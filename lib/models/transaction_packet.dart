import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// ════════════════════════════════════════════════
/// TransactionPacket — حزمة الحوالة
///
/// تمثل حوالة واحدة تنتقل عبر شبكة الـ mesh.
/// تحتوي على:
///   - معلومات الحوالة (المرسل، المستقبل، المبلغ)
///   - توقيع رقمي Ed25519
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
  final String signerPublicKey;
  int ttl;
  List<String> path;

  TransactionPacket({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.amount,
    required this.timestamp,
    required this.signature,
    required this.signerPublicKey,
    this.ttl = 10,
    List<String>? path,
  }) : path = path ?? [];

  // ──────────────────────────────────────────
  //  التوقيع الرقمي — Ed25519
  // ──────────────────────────────────────────

  String signingPayload() {
    return jsonEncode(<String, dynamic>{
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'amount': amount,
      'timestamp': timestamp,
    });
  }

  /// التحقق من صحة التوقيع باستخدام المفتاح العام المرفق.
  Future<bool> verifySignature() async {
    try {
      final algo = Ed25519();
      final sig = Signature(
        base64Decode(signature),
        publicKey: SimplePublicKey(
          base64Decode(signerPublicKey),
          type: KeyPairType.ed25519,
        ),
      );
      return algo.verify(utf8.encode(signingPayload()), signature: sig);
    } catch (_) {
      return false;
    }
  }

  TransactionPacket copyWith({
    String? signature,
    String? signerPublicKey,
    int? ttl,
    List<String>? path,
  }) {
    return TransactionPacket(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      amount: amount,
      timestamp: timestamp,
      signature: signature ?? this.signature,
      signerPublicKey: signerPublicKey ?? this.signerPublicKey,
      ttl: ttl ?? this.ttl,
      path: path ?? List<String>.from(this.path),
    );
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
        'signerPublicKey': signerPublicKey,
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
      signerPublicKey: (json['signerPublicKey'] as String?) ?? '',
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
