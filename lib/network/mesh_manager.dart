import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_packet.dart';
import '../data/local_db.dart';
import 'nearby_mesh_service.dart';

/// ════════════════════════════════════════════════
/// MeshManager — المدير الرئيسي (Singleton)
///
/// يدير كل الشبكة:
///   - NearbyMeshService (BLE + WiFi Direct عبر Google Nearby)
///   - معالجة الحوالات الواردة
///   - منع الحلقات والتكرار
///   - التحقق من التوقيعات
///   - مزامنة مع السيرفر عند عودة الإنترنت
/// ════════════════════════════════════════════════
class MeshManager {
  // ── Singleton ──
  static MeshManager? _instance;
  static MeshManager get instance => _instance ??= MeshManager._();
  MeshManager._();

  /// معرف المستخدم
  String _myUserId = '';
  String get myUserId => _myUserId;
  String get userId => _myUserId;

  /// معرف الجهاز (UUID فريد لهذا الجهاز)
  String _myDeviceId = '';
  String get myDeviceId => _myDeviceId;

  /// خدمة Nearby Connections
  final NearbyMeshService _nearby = NearbyMeshService();

  /// UUID generator
  final _uuid = const Uuid();

  /// Stream للحوالات الواردة (للواجهة)
  final _incomingController = StreamController<TransactionPacket>.broadcast();
  Stream<TransactionPacket> get incomingTransfers => _incomingController.stream;

  /// Stream لحالة الشبكة
  Stream<String> get statusStream => _nearby.statusStream;

  /// Stream لعدد الأجهزة المتصلة
  Stream<int> get peersStream => _nearby.peersStream;

  /// هل المدير يعمل؟
  bool get isRunning => _nearby.isRunning;

  /// عدد الأجهزة المتصلة
  int get connectedCount => _nearby.connectedCount;

  /// أسماء الأجهزة المتصلة
  List<String> get connectedDevices => _nearby.connectedDevices;

  /// سجل الأحداث الحي (للواجهة)
  List<String> get logs => _nearby.logs;
  Stream<String> get logStream => _nearby.logStream;

  // ──────────────────────────────────────────
  //  التهيئة
  // ──────────────────────────────────────────

  /// تهيئة المدير مع معرف المستخدم
  Future<void> initialize(String userId) async {
    _myUserId = userId;
    _myDeviceId = _uuid.v4();

    // تهيئة قاعدة البيانات
    await LocalDB.initialize();

    // إعداد NearbyMeshService
    _nearby.configure(userName: 'JISR_$userId', deviceId: _myDeviceId);
    _nearby.onPacketReceived = onPacketReceived;

    debugPrint('🌐 MeshManager: تم التهيئة');
    debugPrint('🌐 MeshManager: userId=$_myUserId');
    debugPrint('🌐 MeshManager: deviceId=$_myDeviceId');
  }

  // ──────────────────────────────────────────
  //  التشغيل
  // ──────────────────────────────────────────

  /// شغّل الشبكة
  Future<void> start() async {
    debugPrint('🚀 MeshManager: بدء التشغيل...');
    await _nearby.start();
    debugPrint('✅ MeshManager: الشبكة تعمل');
  }

  /// أوقف الشبكة
  Future<void> stop() async {
    await _nearby.stop();
    debugPrint('⏹️ MeshManager: تم الإيقاف');
  }

  // ──────────────────────────────────────────
  //  إنشاء وإرسال حوالة جديدة
  // ──────────────────────────────────────────

  /// إنشاء حوالة جديدة وإرسالها عبر الشبكة
  ///
  /// يخصم الرصيد فوراً (منع double-spending)
  /// يحفظها في pending_txns
  /// تُرسل تلقائياً لجميع الأجهزة المتصلة
  Future<TransactionPacket?> createAndSendTransaction({
    required String receiverId,
    required double amount,
  }) async {
    // 1. تحقق من الرصيد وخصمه فوراً
    final deducted = await LocalDB.debit(amount);
    if (!deducted) {
      debugPrint('❌ MeshManager: رصيد غير كافٍ');
      return null;
    }

    // 2. أنشئ الحوالة
    final txnId = _uuid.v4();
    final signature = TransactionPacket.generateSignature(
      id: txnId,
      amount: amount,
      receiverId: receiverId,
    );

    final txn = TransactionPacket(
      id: txnId,
      senderId: _myUserId,
      receiverId: receiverId,
      amount: amount,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      signature: signature,
      ttl: 10,
      path: [_myDeviceId],
    );

    // 3. احفظها كمعلّقة
    await LocalDB.savePending(txn);

    // 4. أرسلها لجميع الأجهزة المتصلة
    await _nearby.broadcastTransaction(txn);

    debugPrint('📤 MeshManager: حوالة جديدة — $txn');

    return txn;
  }

  // ──────────────────────────────────────────
  //  معالجة الحوالات الواردة
  // ──────────────────────────────────────────

  /// يُستدعى لما نستقبل حوالة من جهاز آخر
  void onPacketReceived(TransactionPacket txn) {
    debugPrint('📥 MeshManager: حوالة واردة — $txn');

    // ── 1. تحقق من التوقيع ──
    if (!txn.verifySignature()) {
      debugPrint('🚫 MeshManager: توقيع خاطئ! تم رفض الحوالة ${txn.id}');
      return;
    }

    // ── 2. تحقق من التكرار ──
    if (LocalDB.isCompleted(txn.id) || LocalDB.hasPending(txn.id)) {
      debugPrint('🔄 MeshManager: حوالة مكررة ${txn.id} — تجاهل');
      return;
    }

    // ── 3. أنا المستقبل؟ ──
    if (txn.receiverId == _myUserId) {
      _handleMyTransaction(txn);
      return;
    }

    // ── 4. أنا وسيط ──
    _handleRelayTransaction(txn);
  }

  /// معالجة حوالة موجّهة لي
  void _handleMyTransaction(TransactionPacket txn) {
    debugPrint('💰 MeshManager: وصلتني حوالة! ${txn.amount}');

    // أضف المبلغ لرصيدي
    LocalDB.credit(txn.amount);

    // سجّلها كمكتملة
    LocalDB.markCompleted(txn);

    // أبلّغ الواجهة
    _incomingController.add(txn);
    debugPrint('🔔 MeshManager: إشعار — وصلك ${txn.amount} من ${txn.senderId}');
  }

  /// معالجة حوالة أنا وسيط فيها
  void _handleRelayTransaction(TransactionPacket txn) {
    // تحقق من ttl
    if (txn.ttl <= 0) {
      debugPrint('🗑️ MeshManager: حوالة ${txn.id} — ttl=0 — حذف');
      return;
    }

    // تحقق من الحلقات
    if (txn.path.contains(_myDeviceId)) {
      debugPrint('🔄 MeshManager: حوالة ${txn.id} — الجهاز موجود في المسار — تجاهل');
      return;
    }

    // أنقص ttl وأضف الجهاز للمسار
    txn.ttl--;
    txn.path.add(_myDeviceId);

    // احفظها كمعلّقة — ستُرسل تلقائياً عند الاتصال بأجهزة أخرى
    LocalDB.savePending(txn);

    // أرسلها فوراً لأي أجهزة متصلة حالياً
    _nearby.broadcastTransaction(txn);

    debugPrint('🔄 MeshManager: وسيط — حوالة ${txn.id} (ttl=${txn.ttl})');
  }

  // ──────────────────────────────────────────
  //  مزامنة عند عودة الإنترنت
  // ──────────────────────────────────────────

  /// عند عودة الإنترنت — ارفع كل الحوالات المعلّقة
  Future<void> onInternetRestored() async {
    final pending = LocalDB.getAllPending();
    debugPrint('🌐 MeshManager: الإنترنت عاد — ${pending.length} حوالات معلّقة');

    for (final txn in pending) {
      final success = await _syncWithServer(txn);
      if (success) {
        await LocalDB.markCompleted(txn);
      }
    }
  }

  Future<bool> _syncWithServer(TransactionPacket txn) async {
    // TODO: مزامنة فعلية مع السيرفر
    debugPrint('☁️ MeshManager: محاكاة مزامنة ${txn.id}');
    return true;
  }

  // ──────────────────────────────────────────
  //  معلومات الحالة
  // ──────────────────────────────────────────

  double getBalance() => LocalDB.getBalance();
  int get pendingCount => LocalDB.getAllPending().length;
  int get completedCount => LocalDB.getAllCompleted().length;
  List<TransactionPacket> get pendingTransactions => LocalDB.getAllPending();
  List<TransactionPacket> get completedTransactions => LocalDB.getAllCompleted();

  // ──────────────────────────────────────────
  //  التنظيف
  // ──────────────────────────────────────────

  void dispose() {
    stop();
    _incomingController.close();
    debugPrint('🌐 MeshManager: تم التنظيف الكامل');
  }
}
