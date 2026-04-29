import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'mesh_manager.dart';

/// ════════════════════════════════════════════════
/// JisrForegroundService — خدمة الخلفية
///
/// تستخدم flutter_foreground_task لـ:
///   - إبقاء BLE و WiFi Aware تعمل حتى لو التطبيق مقفول
///   - عرض إشعار دائم: "جِسر يعمل في الخلفية"
///   - تشغيل MeshManager في الخلفية
/// ════════════════════════════════════════════════
class JisrForegroundService {
  static bool _initialized = false;

  // ──────────────────────────────────────────
  //  التهيئة
  // ──────────────────────────────────────────

  /// إعداد الـ foreground task (يُستدعى مرة واحدة)
  static void initialize() {
    if (_initialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'jisr_mesh_service',
        channelName: 'شبكة جِسر',
        channelDescription: 'خدمة شبكة الطوارئ اللامركزية',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 30000, // كل 30 ثانية
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _initialized = true;
    debugPrint('⚙️ ForegroundService: تمت التهيئة');
  }

  // ──────────────────────────────────────────
  //  بدء الخدمة
  // ──────────────────────────────────────────

  /// ابدأ الخدمة في الخلفية
  static Future<void> start() async {
    initialize();

    // تحقق من الأذونات
    final isGranted = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!isGranted) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    // ابدأ الخدمة
    await FlutterForegroundTask.startService(
      notificationTitle: 'جِسر يعمل في الخلفية',
      notificationText: 'شبكة الطوارئ نشطة 🔵',
      callback: _startCallback,
    );

    debugPrint('🟢 ForegroundService: الخدمة تعمل');
  }

  /// إيقاف الخدمة
  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
    debugPrint('🔴 ForegroundService: تم إيقاف الخدمة');
  }

  /// تحديث نص الإشعار
  static Future<void> updateNotification({
    String? title,
    String? text,
  }) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: title ?? 'جِسر يعمل في الخلفية',
      notificationText: text ?? 'شبكة الطوارئ نشطة 🔵',
    );
  }
}

// ══════════════════════════════════════════════
//  Callback — يعمل في الخلفية
// ══════════════════════════════════════════════

/// Entry point للـ foreground task
@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_JisrTaskHandler());
}

/// معالج المهام في الخلفية
class _JisrTaskHandler extends TaskHandler {
  @override
  void onStart(DateTime timestamp, SendPort? sendPort) {
    debugPrint('🟢 TaskHandler: بدء المعالج — $timestamp');
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {
    // يُستدعى كل 30 ثانية
    final manager = MeshManager.instance;
    if (manager.isRunning) {
      final pending = manager.pendingCount;
      final completed = manager.completedCount;

      // حدّث الإشعار بالحالة
      FlutterForegroundTask.updateService(
        notificationTitle: 'جِسر يعمل في الخلفية',
        notificationText: 'شبكة الطوارئ نشطة 🔵 | '
            'معلّقة: $pending | مكتملة: $completed',
      );
    }
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {
    debugPrint('🔴 TaskHandler: تم إيقاف المعالج — $timestamp');
  }
}
