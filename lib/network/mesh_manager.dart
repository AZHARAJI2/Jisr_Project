import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_packet.dart';
import '../data/local_db.dart';
import 'nearby_mesh_service.dart';
import 'security_service.dart';
import 'notification_service.dart';

class TransferTracePoint {
  final String txnId;
  final String nodeId;
  final String state;
  final int timestamp;
  final List<String> path;

  const TransferTracePoint({
    required this.txnId,
    required this.nodeId,
    required this.state,
    required this.timestamp,
    required this.path,
  });
}

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
  final _traceController = StreamController<TransferTracePoint>.broadcast();
  Stream<TransferTracePoint> get traceStream => _traceController.stream;
  final Map<String, List<TransferTracePoint>> _traceByTxn = {};

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
  List<PeerTelemetry> get peerTelemetry => _nearby.getPeerTelemetry();

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
    await SecurityService.instance.initialize();
    await _nearby.configure(
      userName: 'JISR_$userId',
      deviceId: _myDeviceId,
      userId: _myUserId,
    );
    _nearby.onPacketReceived = onPacketReceived;
    _nearby.onTraceReceived = _onTraceReceived;

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
    final unsigned = TransactionPacket(
      id: txnId,
      senderId: _myUserId,
      receiverId: receiverId,
      amount: amount,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      signature: '',
      signerPublicKey: SecurityService.instance.signingPublicKeyB64,
      ttl: 10,
      path: [_myDeviceId],
    );
    final signature = await SecurityService.instance.signToB64(
      unsigned.signingPayload().codeUnits,
    );

    final txn = TransactionPacket(
      id: txnId,
      senderId: _myUserId,
      receiverId: receiverId,
      amount: amount,
      timestamp: unsigned.timestamp,
      signature: signature,
      signerPublicKey: SecurityService.instance.signingPublicKeyB64,
      ttl: 10,
      path: [_myDeviceId],
    );

    // 3. احفظها كمعلّقة
    await LocalDB.savePending(txn);

    // 4. أرسلها لجميع الأجهزة المتصلة
    await _nearby.broadcastTransaction(txn);
    await _recordAndPublishTrace(
      txnId: txn.id,
      state: 'sent',
      path: txn.path,
    );

    debugPrint('📤 MeshManager: حوالة جديدة — $txn');

    return txn;
  }

  // ──────────────────────────────────────────
  //  معالجة الحوالات الواردة
  // ──────────────────────────────────────────

  /// يُستدعى لما نستقبل حوالة من جهاز آخر
  Future<void> onPacketReceived(TransactionPacket txn) async {
    debugPrint('📥 MeshManager: حوالة واردة — $txn');

    // ── 1. تحقق من التوقيع ──
    if (!await txn.verifySignature()) {
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
      await _handleMyTransaction(txn);
      return;
    }

    // ── 4. أنا وسيط ──
    await _handleRelayTransaction(txn);
  }

  /// معالجة حوالة موجّهة لي
  Future<void> _handleMyTransaction(TransactionPacket txn) async {
    debugPrint('💰 MeshManager: وصلتني حوالة! ${txn.amount}');

    // أضف المبلغ لرصيدي
    await LocalDB.credit(txn.amount);

    // سجّلها كمكتملة
    await LocalDB.markCompleted(txn);

    // أبلّغ الواجهة
    _incomingController.add(txn);
    await NotificationService.instance.showIncomingTransfer(
      senderId: txn.senderId,
      amount: txn.amount,
    );
    await _recordAndPublishTrace(
      txnId: txn.id,
      state: 'delivered',
      path: txn.path,
    );
    debugPrint('🔔 MeshManager: إشعار — وصلك ${txn.amount} من ${txn.senderId}');
  }

  /// معالجة حوالة أنا وسيط فيها
  Future<void> _handleRelayTransaction(TransactionPacket txn) async {
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
    await LocalDB.savePending(txn);

    // أرسلها فوراً لأي أجهزة متصلة حالياً
    await _nearby.broadcastTransaction(txn);
    await _recordAndPublishTrace(
      txnId: txn.id,
      state: 'relayed',
      path: txn.path,
    );

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
  List<TransferTracePoint> getTrace(String txnId) =>
      List.unmodifiable(_traceByTxn[txnId] ?? const []);

  Future<void> _recordAndPublishTrace({
    required String txnId,
    required String state,
    required List<String> path,
  }) async {
    final point = TransferTracePoint(
      txnId: txnId,
      nodeId: _myUserId,
      state: state,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      path: List<String>.from(path),
    );
    _traceByTxn.putIfAbsent(txnId, () => []).add(point);
    _traceController.add(point);
    await _nearby.publishTraceEvent(
      txnId: txnId,
      state: state,
      path: point.path,
    );
  }

  Future<void> _onTraceReceived(Map<String, dynamic> trace) async {
    final txnId = trace['txnId'] as String? ?? '';
    if (txnId.isEmpty) return;
    final point = TransferTracePoint(
      txnId: txnId,
      nodeId: trace['nodeId'] as String? ?? 'unknown',
      state: trace['state'] as String? ?? 'unknown',
      timestamp: (trace['ts'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      path: (trace['path'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
    final bucket = _traceByTxn.putIfAbsent(txnId, () => []);
    final duplicate = bucket.any(
      (p) => p.nodeId == point.nodeId && p.state == point.state && p.timestamp == point.timestamp,
    );
    if (duplicate) return;
    bucket.add(point);
    bucket.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _traceController.add(point);
  }

  // ──────────────────────────────────────────
  //  التنظيف
  // ──────────────────────────────────────────

  void dispose() {
    stop();
    _incomingController.close();
    _traceController.close();
    debugPrint('🌐 MeshManager: تم التنظيف الكامل');
  }
}
