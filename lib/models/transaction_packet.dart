import 'dart:convert';
import 'package:crypto/crypto.dart';

/// ════════════════════════════════════════════════
/// TransactionPacket — حزمة الحوالة
///
/// تمثل حوالة واحدة تنتقل عبر شبكة الـ mesh.
/// تحتوي على:
///   - معلومات الحوالة (المرسل، المستقبل، المبلغ)
///   - توقيع رقمي SHA-256
///   - ttl — عدد القفزات المتبقية
///   - path — سجل الأجهزة اللي عبرت منها
/// ════════════════════════════════════════════════
class TransactionPacket {
  final String id;
  final String senderId;
  final String receiverId;
  final double amount;
  final int timestamp;
  final String signature;
  int ttl;
  List<String> path;

  TransactionPacket({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.amount,
    required this.timestamp,
    required this.signature,
    this.ttl = 10,
    List<String>? path,
  }) : path = path ?? [];

  // ──────────────────────────────────────────
  //  التوقيع الرقمي — SHA-256
  // ──────────────────────────────────────────

  /// إنشاء توقيع SHA-256 على (id + amount + receiverId)
  static String generateSignature({
    required String id,
    required double amount,
    required String receiverId,
  }) {
    final data = '$id$amount$receiverId';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// التحقق من صحة التوقيع
  bool verifySignature() {
    final expected = generateSignature(
      id: id,
      amount: amount,
      receiverId: receiverId,
    );
    return signature == expected;
  }

  // ──────────────────────────────────────────
  //  التحويل من/إلى JSON
  // ──────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'receiverId': receiverId,
        'amount': amount,
        'timestamp': timestamp,
        'signature': signature,
        'ttl': ttl,
        'path': path,
      };

  factory TransactionPacket.fromJson(Map<String, dynamic> json) {
    return TransactionPacket(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      amount: (json['amount'] as num).toDouble(),
      timestamp: json['timestamp'] as int,
      signature: json['signature'] as String,
      ttl: json['ttl'] as int? ?? 10,
      path: (json['path'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  /// تحويل إلى JSON string للإرسال عبر BLE
  String toJsonString() => jsonEncode(toJson());

  /// إنشاء من JSON string (بيانات BLE الواردة)
  factory TransactionPacket.fromJsonString(String jsonStr) {
    return TransactionPacket.fromJson(
      jsonDecode(jsonStr) as Map<String, dynamic>,
    );
  }

  @override
  String toString() =>
      'TXN[$id] $senderId → $receiverId | $amount | ttl=$ttl | path=${path.length} hops';
}
