import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:async';

// ── الشبكة والبيانات ──
import 'network/network.dart';
import 'data/data.dart';

// ── واجهات زميلك ──
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'providers/user_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDB.initialize();
  await NotificationService.instance.initialize();
  runApp(
    ChangeNotifierProvider(
      create: (_) => UserProvider(),
      child: const CrisisBridgeApp(),
    ),
  );
}

class CrisisBridgeApp extends StatelessWidget {
  const CrisisBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'جسر - Jisr',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: WithForegroundTask(child: const MeshBootstrap()),
    );
  }
}

/// ─────────────────────────────────────────────
///  يبدأ الشبكة في الخلفية ثم يعرض SplashScreen
/// ─────────────────────────────────────────────
class MeshBootstrap extends StatefulWidget {
  const MeshBootstrap({super.key});

  @override
  State<MeshBootstrap> createState() => _MeshBootstrapState();
}

class _MeshBootstrapState extends State<MeshBootstrap> {
  @override
  void initState() {
    super.initState();
    _initMesh();
  }

  Future<void> _initMesh() async {
    // ── الصلاحيات ──
    await Permission.location.request();
    await Permission.locationWhenInUse.request();
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();
    await Permission.nearbyWifiDevices.request();
    await Permission.notification.request();

    // ── معرّف المستخدم ──
    final idBox = await Hive.openBox('device_id');
    var userId = idBox.get('userId') as String? ?? '';
    if (userId.isEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      userId = 'user_${now % 100000}';
      await idBox.put('userId', userId);
    }
    debugPrint('🆔 معرّف المستخدم: $userId');

    // ── تشغيل الشبكة ──
    final mesh = MeshManager.instance;
    await mesh.initialize(userId);
    await mesh.start();

    // ── خدمة الخلفية ──
    // موقوفة مؤقتا: تشغيل ForegroundTask ينشئ Flutter engine إضافي،
    // ومع القنوات static داخل البلجن قد تذهب أحداث jisr_events للمحرك الخلفي
    // بدل واجهة التطبيق، فيظهر عدد الأجهزة = 0 رغم نجاح الاتصال.
    // أعد التفعيل لاحقا بعد جعل قنوات البلجن non-static/multi-engine safe.
    // try {
    //   await JisrForegroundService.start();
    // } catch (e) {
    //   debugPrint('⚠️ Foreground service: $e');
    // }
  }

  @override
  Widget build(BuildContext context) {
    // نعرض SplashScreen مباشرة — الشبكة تعمل في الخلفية
    return const SplashScreen();
  }
}