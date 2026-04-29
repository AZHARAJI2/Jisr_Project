# 👨‍💻 دليل كل مطور — جسر الأزمات
### اقرأ جزئيتك كاملاً قبل ما تكتب سطر كود

---

## ⚠️ قبل كل شيء — اتفقوا على هذا

هذه البيانات المشتركة بينكم الثلاثة — كلكم يستخدمها بنفس الشكل:

```dart
// نموذج التحويل — الكل يستخدمه
class TransferPacket {
  final String id;          // رقم فريد للتحويل
  final String fromUserId;  // المرسِل
  final String toUserId;    // المستلم
  final double amount;      // المبلغ
  final DateTime timestamp; // وقت الإرسال
  final String signature;   // توقيع التشفير
  final String status;      // pending / completed / failed

  Map<String, dynamic> toJson() => {
    'id': id,
    'from': fromUserId,
    'to': toUserId,
    'amount': amount,
    'time': timestamp.toIso8601String(),
    'signature': signature,
    'status': status,
  };

  factory TransferPacket.fromJson(Map<String, dynamic> json) =>
    TransferPacket(
      id: json['id'],
      fromUserId: json['from'],
      toUserId: json['to'],
      amount: json['amount'],
      timestamp: DateTime.parse(json['time']),
      signature: json['signature'],
      status: json['status'],
    );
}

// نموذج الهاتف القريب — الكل يستخدمه
class NetworkNode {
  final String deviceId;
  final int batteryLevel;      // 0-100
  final int signalStrength;    // 0-100
  final int activeTransfers;   // عدد التحويلات النشطة
  final bool hasInternet;      // عنده إنترنت؟
  final double proximityScore; // 0-1 (كلما أكبر كلما أقرب)
  final List<String> neighbors; // الهواتف اللي يراها
}
```

---

---

# 👨‍💻 الشخص الأول — مطور الشبكة

## مهمتك بكلمة واحدة
```
أنت اللي تخلي الهواتف تتكلم مع بعض
بدون إنترنت
```

---

## ايش بتبني بالضبط؟

### الجزء 1 — اكتشاف الهواتف القريبة

```
التطبيق يبحث كل 70 ثانية عن هواتف قريبة
يستخدم WiFi Direct أولاً
لو فشل يستخدم Bluetooth
```

```dart
class MeshDiscovery {

  // ابحث عن الهواتف القريبة
  Future<List<NetworkNode>> scanNearbyDevices() async {
    List<NetworkNode> found = [];

    // جرب WiFi Direct أولاً
    try {
      final wifiDevices = await WiFiP2P.discoverDevices();
      found.addAll(wifiDevices.map((d) => d.toNetworkNode()));
    } catch (e) {
      // WiFi Direct فشل — جرب Bluetooth
      final btDevices = await FlutterBluePlus.scan(
        timeout: Duration(seconds: 10),
      );
      found.addAll(btDevices.map((d) => d.toNetworkNode()));
    }

    return found;
  }
}
```

---

### الجزء 2 — إرسال التحويل عبر الشبكة

```
المستخدم يضغط "إرسال"
أنت تأخذ التحويل وتبعثه
للهاتف الأفضل درجةً (الشخص الثاني يعطيك هذا)
```

```dart
class MeshSender {

  Future<bool> sendTransfer(
    TransferPacket packet,
    List<NetworkNode> sortedNodes, // يجيك من الشخص الثاني
  ) async {
    for (var node in sortedNodes) {
      bool sent = await _sendToNode(packet, node);
      if (sent) return true;
    }
    return false; // كل المحاولات فشلت
  }

  Future<bool> _sendToNode(TransferPacket packet, NetworkNode node) async {
    try {
      // حوّل التحويل لـ bytes مشفرة
      String encrypted = encryptPacket(packet); // من الشخص الثالث
      
      // أرسل عبر WiFi Direct
      await WiFiP2P.sendData(node.deviceId, encrypted);
      return true;
    } catch (e) {
      return false;
    }
  }
}
```

---

### الجزء 3 — استقبال التحويلات من الهواتف الأخرى

```
هاتفك ممكن يكون وسيطاً
يستقبل تحويل شخص آخر ويمرّره

مهمتك: استقبله وأعِد إرساله للأمام
```

```dart
class MeshReceiver {

  void startListening() {
    WiFiP2P.onDataReceived.listen((encryptedData) async {

      // فك التشفير (من الشخص الثالث)
      TransferPacket packet = decryptPacket(encryptedData);

      // هل هذا التحويل لي أنا؟
      if (packet.toUserId == myUserId) {
        // وصلني تحويل! أبلّغ الواجهة
        onTransferReceived(packet);
      } else {
        // أنا وسيط — مرّره للأمام
        await relayTransfer(packet);
      }
    });
  }

  Future<void> relayTransfer(TransferPacket packet) async {
    // أرسله لأفضل هاتف قريب
    // نفس منطق الإرسال
    await MeshSender().sendTransfer(packet, nearbyNodes);
  }
}
```

---

## المكتبات اللي بتستخدمها

```yaml
flutter_p2p_connection: ^latest   # WiFi Direct
flutter_blue_plus: ^latest         # Bluetooth
```

---

## ايش يهمك تعرفه عن الآخرين

```
من الشخص الثاني تحتاج:
→ دالة تعطيك List<NetworkNode> مرتبة حسب الأفضلية
   اسمها: getOptimalPath(List<NetworkNode> nodes)

من الشخص الثالث تحتاج:
→ دالة تشفير:   String encryptPacket(TransferPacket p)
→ دالة فك تشفير: TransferPacket decryptPacket(String data)
```

---

## نقطة الربط مع الواجهة

```dart
// الواجهة تستدعي هذا لما يضغط المستخدم "إرسال"
Future<bool> initiateTransfer(TransferPacket packet) async {
  final nodes = await MeshDiscovery().scanNearbyDevices();
  final sorted = SmartRouter().getOptimalPath(nodes); // من الشخص الثاني
  return await MeshSender().sendTransfer(packet, sorted);
}

// الواجهة تسمع على هذا لما يصل تحويل
Stream<TransferPacket> get incomingTransfers =>
  MeshReceiver().transferStream;
```

---

---

# 👨‍💻 الشخص الثاني — مطور الذكاء الاصطناعي والخريطة

## مهمتك بكلمة واحدة
```
أنت عقل التطبيق
تقرر أي مسار يسلكه التحويل
وترسم الخريطة الحية
```

---

## ايش بتبني بالضبط؟

### الجزء 1 — خوارزمية المسار الذكي

```
تأخذ قائمة الهواتف القريبة
تحسب درجة كل واحد
ترجعها مرتبة من الأفضل للأسوأ
```

```dart
class SmartRouter {

  // هذه الدالة هي اللي يحتاجها الشخص الأول
  List<NetworkNode> getOptimalPath(List<NetworkNode> nodes) {
    // احسب درجة كل هاتف
    final scored = nodes.map((node) => {
      'node': node,
      'score': _calculateScore(node),
    }).toList();

    // رتّب من الأعلى للأقل
    scored.sort((a, b) => (b['score'] as double)
      .compareTo(a['score'] as double));

    return scored.map((s) => s['node'] as NetworkNode).toList();
  }

  double _calculateScore(NetworkNode node) {
    double score = 0;

    // البطارية — 40%
    score += (node.batteryLevel / 100) * 40;

    // قوة الإشارة — 30%
    score += (node.signalStrength / 100) * 30;

    // التحويلات النشطة — 20%
    // كلما أقل كلما أفضل
    double penalty = (node.activeTransfers * 5).clamp(0.0, 20.0);
    score += (20 - penalty);

    // القرب من الهدف — 10%
    score += node.proximityScore * 10;

    return score.clamp(0, 100);
  }
}
```

---

### الجزء 2 — ترشيد البطارية

```
التطبيق لا يبحث باستمرار
ينام 60 ثانية → يبحث 10 ثوان → ينام

لو البطارية أقل من 20% → ينام أطول
```

```dart
class BatteryAwareScanner {

  bool isRunning = false;

  void start() {
    isRunning = true;
    _scanLoop();
  }

  void stop() => isRunning = false;

  Future<void> _scanLoop() async {
    while (isRunning) {
      // ابحث 10 ثوان
      await MeshDiscovery().scanNearbyDevices();

      // كم تنام؟
      int battery = await getBatteryLevel();
      int sleepSeconds = battery < 20 ? 120 : 60;

      await Future.delayed(Duration(seconds: sleepSeconds));
    }
  }
}
```

---

### الجزء 3 — محاكي الشبكة (للعرض)

```
لو ما عندكم هواتف كثيرة —
هذا يولّد شبكة وهمية للعرض أمام الحكّام
```

```dart
class NetworkSimulator {

  List<NetworkNode> generateDemoNetwork() {
    return [
      NetworkNode(deviceId:"خالد",  batteryLevel:90, signalStrength:85, activeTransfers:0, hasInternet:false, proximityScore:0.9),
      NetworkNode(deviceId:"محمد",  batteryLevel:70, signalStrength:75, activeTransfers:1, hasInternet:false, proximityScore:0.7),
      NetworkNode(deviceId:"علي",   batteryLevel:95, signalStrength:90, activeTransfers:0, hasInternet:true,  proximityScore:0.5),
      NetworkNode(deviceId:"سارة",  batteryLevel:30, signalStrength:60, activeTransfers:2, hasInternet:false, proximityScore:0.8),
      NetworkNode(deviceId:"أحمد",  batteryLevel:15, signalStrength:45, activeTransfers:0, hasInternet:false, proximityScore:0.6),
    ];
  }
}
```

---

### الجزء 4 — خارطة الأمان

```
كل هاتف يبث ما يراه
أنت تجمع هذه البيانات وترسمها على الخريطة
```

```dart
class SafetyMapBuilder {

  // ابنِ الخريطة من بيانات الهواتف القريبة
  List<MapNode> buildMap(List<NetworkNode> allNodes) {
    return allNodes.map((node) => MapNode(
      id: node.deviceId,
      // احسب الموقع من قوة الإشارة
      x: _calculateX(node.signalStrength),
      y: _calculateY(node.signalStrength),
      color: _getColor(node),
      label: node.deviceId,
      isInternet: node.hasInternet,
    )).toList();
  }

  Color _getColor(NetworkNode node) {
    if (node.hasInternet) return Colors.blue;    // 🔵 عنده إنترنت
    if (node.batteryLevel > 60) return Colors.green;  // 🟢 ممتاز
    if (node.batteryLevel > 30) return Colors.orange; // 🟡 جيد
    return Colors.red;                                 // 🔴 ضعيف
  }
}
```

---

## المكتبات اللي بتستخدمها

```yaml
flutter_map: ^latest    # رسم الخريطة
battery_plus: ^latest   # مستوى البطارية
```

---

## ايش يهمك تعرفه عن الآخرين

```
للشخص الأول تعطيه:
→ دالة: getOptimalPath(List<NetworkNode> nodes)

للواجهة تعطيها:
→ Stream<List<NetworkNode>> nearbyNodesStream
  (تتحدث كل 30 ثانية)
→ List<MapNode> buildMap(List<NetworkNode> nodes)
```

---

---

# 👨‍💻 الشخص الثالث — مطور البيانات والمنطق

## مهمتك بكلمة واحدة
```
أنت أمان وذاكرة التطبيق
تحفظ البيانات وتشفّرها
وتضمن وصول الإشعار للمستلم
```

---

## ايش بتبني بالضبط؟

### الجزء 1 — التخزين المحلي (Hive)

```
يحفظ رصيد المستخدم محلياً
حتى بدون إنترنت
```

```dart
class LocalWallet {

  // احفظ الرصيد محلياً
  Future<void> saveBalance(double balance) async {
    final box = await Hive.openBox('wallet');
    await box.put('balance', balance);
  }

  // اقرأ الرصيد
  Future<double> getBalance() async {
    final box = await Hive.openBox('wallet');
    return box.get('balance', defaultValue: 0.0);
  }

  // خصم فوري — يمنع Double-Spending
  Future<bool> deductBalance(double amount) async {
    final box = await Hive.openBox('wallet');
    double current = box.get('balance', defaultValue: 0.0);

    if (current < amount) return false; // رصيد غير كافٍ

    // خصم فوري قبل الإرسال
    await box.put('balance', current - amount);
    return true;
  }

  // أعِد الرصيد لو فشل الإرسال
  Future<void> refundBalance(double amount) async {
    final box = await Hive.openBox('wallet');
    double current = box.get('balance', defaultValue: 0.0);
    await box.put('balance', current + amount);
  }

  // احفظ التحويل في السجل
  Future<void> saveTransfer(TransferPacket packet) async {
    final box = await Hive.openBox('transfers');
    await box.put(packet.id, packet.toJson());
  }
}
```

---

### الجزء 2 — التشفير

```
كل تحويل يُشفَّر قبل ما يخرج من الهاتف
الهواتف الوسيطة ما تشوف المحتوى
```

```dart
class TransferEncryption {

  // مفتاح ثابت للهاكاثون
  // في الإنتاج الحقيقي يكون مختلف لكل مستخدم
  final _key = Key.fromUtf8('crisis_bridge_key_32_chars_long!');
  final _iv  = IV.fromUtf8('crisis_bridge_iv');

  // شفّر التحويل
  // الشخص الأول يستدعي هذه
  String encryptPacket(TransferPacket packet) {
    final encrypter = Encrypter(AES(_key));
    return encrypter.encrypt(
      jsonEncode(packet.toJson()),
      iv: _iv,
    ).base64;
  }

  // فك التشفير
  // الشخص الأول يستدعي هذه
  TransferPacket decryptPacket(String encrypted) {
    final encrypter = Encrypter(AES(_key));
    final decrypted = encrypter.decrypt64(encrypted, iv: _iv);
    return TransferPacket.fromJson(jsonDecode(decrypted));
  }
}
```

---

### الجزء 3 — Firebase (السيرفر والإشعارات)

```
لما التحويل يوصل لشخص عنده إنترنت:
→ يرفعه للسيرفر
→ السيرفر يرسل إشعار فوري للمستلم
```

```dart
class FirebaseService {

  // ارفع التحويل للسيرفر
  // يُستدعى لما يوصل التحويل لهاتف عنده إنترنت
  Future<bool> uploadTransfer(TransferPacket packet) async {
    try {
      await FirebaseFirestore.instance
        .collection('transfers')
        .doc(packet.id)
        .set(packet.toJson());
      return true;
    } catch (e) {
      return false;
    }
  }

  // أرسل إشعار للمستلم
  Future<void> notifyReceiver(TransferPacket packet) async {
    // احصل على FCM Token للمستلم
    final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(packet.toUserId)
      .get();

    String? fcmToken = userDoc.data()?['fcmToken'];
    if (fcmToken == null) return;

    // أرسل الإشعار
    await FirebaseFirestore.instance
      .collection('notifications')
      .add({
        'token': fcmToken,
        'title': '💰 وصلك تحويل!',
        'body': 'وصلك ${packet.amount} ريال',
        'data': packet.toJson(),
        'time': DateTime.now().toIso8601String(),
      });
  }

  // استمع على التحويلات الجديدة (للمستلم)
  Stream<TransferPacket> listenForIncomingTransfers(String userId) {
    return FirebaseFirestore.instance
      .collection('transfers')
      .where('to', isEqualTo: userId)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) => snap.docs
        .map((doc) => TransferPacket.fromJson(doc.data()))
        .first);
  }
}
```

---

### الجزء 4 — المنطق الكامل للإرسال

```
هذا هو تسلسل العمليات الكامل
من لحظة ضغط "إرسال" حتى وصول التحويل
```

```dart
class TransferManager {

  Future<TransferResult> send({
    required String toUserId,
    required double amount,
  }) async {

    // 1. تحقق من الرصيد وخصم فوراً
    bool deducted = await LocalWallet().deductBalance(amount);
    if (!deducted) {
      return TransferResult.failed('رصيد غير كافٍ');
    }

    // 2. أنشئ التحويل
    final packet = TransferPacket(
      id: generateUniqueId(),
      fromUserId: myUserId,
      toUserId: toUserId,
      amount: amount,
      timestamp: DateTime.now(),
      signature: generateSignature(),
      status: 'pending',
    );

    // 3. احفظه محلياً
    await LocalWallet().saveTransfer(packet);

    // 4. أرسل عبر الشبكة (الشخص الأول)
    bool sent = await MeshNetwork().initiateTransfer(packet);

    if (!sent) {
      // فشل — أعِد الرصيد
      await LocalWallet().refundBalance(amount);
      return TransferResult.failed('فشل الإرسال');
    }

    return TransferResult.success(packet);
  }
}
```

---

## المكتبات اللي بتستخدمها

```yaml
hive: ^latest              # التخزين المحلي
hive_flutter: ^latest
encrypt: ^latest           # التشفير
firebase_core: ^latest     # Firebase
cloud_firestore: ^latest   # قاعدة البيانات
firebase_messaging: ^latest # الإشعارات
```

---

## ايش يهمك تعرفه عن الآخرين

```
للشخص الأول تعطيه:
→ encryptPacket(TransferPacket p) → String
→ decryptPacket(String data) → TransferPacket

للواجهة تعطيها:
→ TransferManager().send(toUserId, amount)
→ LocalWallet().getBalance()
→ Stream<TransferPacket> للتحويلات الواردة
```

---

---

# 🔗 جدول الربط بين الثلاثة

```
┌─────────────────────────────────────────────────┐
│              الواجهة (الشخص الرابع)             │
└──────┬──────────────┬───────────────┬────────────┘
       │              │               │
       ▼              ▼               ▼
┌──────────┐  ┌──────────────┐  ┌──────────────┐
│ ش1 شبكة │  │ ش2 AI+خريطة │  │ ش3 بيانات   │
│          │  │              │  │              │
│ يحتاج   │◄─│ getOptimal   │  │ يعطي        │
│ من ش2:  │  │ Path()       │  │ encrypt()   │─►│ ش1
│         │  │              │  │ decrypt()   │
│ يحتاج  │◄─────────────────────│ getBalance()│
│ من ش3:  │  │              │  │ deduct()    │
│ encrypt │  │              │  │ firebase    │
│ decrypt │  │              │  │             │
└──────────┘  └──────────────┘  └──────────────┘
```

---

# 📋 اتفقوا على هذا قبل البداية

```
① نفس اسم الدوال — لا يغيرها أحد
② نفس نموذج البيانات (TransferPacket + NetworkNode)
③ كل شخص يعمل على Branch منفصل في GitHub
④ الدمج يصير في اليوم الثاني الصباح
⑤ لو في مشكلة — تكلموا فوراً لا تنتظرون
```

---

*🌉 جسر الأزمات — SalamHack 2026*
