import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction_packet.dart';

/// ════════════════════════════════════════════════
/// LocalDB — قاعدة البيانات المحلية (Hive)
///
/// ثلاثة صناديق:
///   balance        → الرصيد الحالي
///   pending_txns   → حوالات لم تصل (معلّقة)
///   completed_txns → حوالات مكتملة
///
/// قواعد:
///   - الخصم الفوري عند الإرسال (منع double-spending)
///   - لا تسمح بإرسال إذا balance < amount
/// ════════════════════════════════════════════════
class LocalDB {
  static const String _balanceBox = 'balance';
  static const String _pendingBox = 'pending_txns';
  static const String _completedBox = 'completed_txns';

  static bool _initialized = false;

  // ──────────────────────────────────────────
  //  التهيئة
  // ──────────────────────────────────────────

  /// تهيئة Hive وفتح جميع الصناديق
  static Future<void> initialize() async {
    if (_initialized) return;
    await Hive.initFlutter();
    await Hive.openBox(_balanceBox);
    await Hive.openBox(_pendingBox);
    await Hive.openBox(_completedBox);
    _initialized = true;
    debugPrint('💾 LocalDB: تم التهيئة — جميع الصناديق مفتوحة');
  }

  // ──────────────────────────────────────────
  //  إدارة الرصيد
  // ──────────────────────────────────────────

  /// الحصول على الرصيد الحالي
  static double getBalance() {
    final box = Hive.box(_balanceBox);
    return (box.get('current', defaultValue: 100000.0) as num).toDouble();
  }

  /// تعيين الرصيد مباشرة
  static Future<void> setBalance(double amount) async {
    final box = Hive.box(_balanceBox);
    await box.put('current', amount);
  }

  /// خصم مبلغ من الرصيد — يرفض إذا الرصيد غير كافٍ
  /// يُستدعى فوراً عند إنشاء حوالة جديدة (منع double-spending)
  static Future<bool> debit(double amount) async {
    final current = getBalance();
    if (current < amount) {
      debugPrint('❌ LocalDB: رصيد غير كافٍ — المطلوب: $amount، المتاح: $current');
      return false;
    }
    await setBalance(current - amount);
    debugPrint('💸 LocalDB: تم خصم $amount — الرصيد الجديد: ${current - amount}');
    return true;
  }

  /// إضافة مبلغ للرصيد (عند استلام حوالة)
  static Future<void> credit(double amount) async {
    final current = getBalance();
    await setBalance(current + amount);
    debugPrint('💰 LocalDB: تم إضافة $amount — الرصيد الجديد: ${current + amount}');
  }

  // ──────────────────────────────────────────
  //  الحوالات المعلّقة (Pending)
  // ──────────────────────────────────────────

  /// حفظ حوالة معلّقة (للإرسال/التمرير لاحقاً)
  static Future<void> savePending(TransactionPacket txn) async {
    final box = Hive.box(_pendingBox);
    await box.put(txn.id, txn.toJson());
    debugPrint('📋 LocalDB: حوالة معلّقة محفوظة — ${txn.id}');
  }

  /// جلب جميع الحوالات المعلّقة
  static List<TransactionPacket> getAllPending() {
    final box = Hive.box(_pendingBox);
    final packets = <TransactionPacket>[];
    for (final key in box.keys) {
      final json = box.get(key);
      if (json != null) {
        try {
          packets.add(
            TransactionPacket.fromJson(Map<String, dynamic>.from(json as Map)),
          );
        } catch (e) {
          debugPrint('⚠️ LocalDB: تعذر قراءة حوالة معلّقة $key: $e');
        }
      }
    }
    return packets;
  }

  /// جلب حوالة معلّقة بالمعرّف
  static TransactionPacket? getPendingById(String txnId) {
    final box = Hive.box(_pendingBox);
    final json = box.get(txnId);
    if (json == null) return null;
    try {
      return TransactionPacket.fromJson(Map<String, dynamic>.from(json as Map));
    } catch (e) {
      debugPrint('⚠️ LocalDB: تعذر قراءة حوالة معلّقة $txnId: $e');
      return null;
    }
  }

  /// حذف حوالة معلّقة (بعد إتمامها أو انتهاء صلاحيتها)
  static Future<void> removePending(String txnId) async {
    final box = Hive.box(_pendingBox);
    await box.delete(txnId);
    debugPrint('🗑️ LocalDB: تم حذف حوالة معلّقة — $txnId');
  }

  /// هل هذه الحوالة موجودة مسبقاً؟ (لمنع التكرار)
  static bool hasPending(String txnId) {
    final box = Hive.box(_pendingBox);
    return box.containsKey(txnId);
  }

  // ──────────────────────────────────────────
  //  الحوالات المكتملة (Completed)
  // ──────────────────────────────────────────

  /// نقل حوالة من المعلّقة إلى المكتملة
  static Future<void> markCompleted(TransactionPacket txn) async {
    // أضف للمكتملة
    final completedBox = Hive.box(_completedBox);
    await completedBox.put(txn.id, txn.toJson());

    // احذف من المعلّقة
    await removePending(txn.id);
    debugPrint('✅ LocalDB: حوالة مكتملة — ${txn.id}');
  }

  /// جلب جميع الحوالات المكتملة
  static List<TransactionPacket> getAllCompleted() {
    final box = Hive.box(_completedBox);
    final packets = <TransactionPacket>[];
    for (final key in box.keys) {
      final json = box.get(key);
      if (json != null) {
        try {
          packets.add(
            TransactionPacket.fromJson(Map<String, dynamic>.from(json as Map)),
          );
        } catch (e) {
          debugPrint('⚠️ LocalDB: تعذر قراءة حوالة مكتملة $key: $e');
        }
      }
    }
    return packets;
  }

  /// هل استلمنا هذه الحوالة مسبقاً؟ (لمنع المعالجة المكررة)
  static bool isCompleted(String txnId) {
    final box = Hive.box(_completedBox);
    return box.containsKey(txnId);
  }
}
