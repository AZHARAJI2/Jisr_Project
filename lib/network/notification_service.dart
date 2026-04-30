import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: androidInit);
    await _plugin.initialize(init);

    const channel = AndroidNotificationChannel(
      'jisr_transfers',
      'Jisr Transfers',
      description: 'Notifications for incoming mesh transfers',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<void> showIncomingTransfer({
    required String senderId,
    required double amount,
  }) async {
    await initialize();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'jisr_transfers',
        'Jisr Transfers',
        channelDescription: 'Notifications for incoming mesh transfers',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'حوالة جديدة وصلت',
      'وصلك $amount من $senderId',
      details,
    );
  }

  Future<void> showSentTransfer({
    required String receiverId,
    required double amount,
  }) async {
    await initialize();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'jisr_transfers',
        'Jisr Transfers',
        channelDescription: 'Notifications for incoming mesh transfers',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'تم إرسال الحوالة',
      'أرسلت $amount إلى $receiverId',
      details,
    );
  }
}
