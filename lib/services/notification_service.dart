import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final _local = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'luma_channel';
  static const _channelName = 'Luma Notifications';

  static Future<void> init() async {
    const android  = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _local.initialize(settings);

    // Resolve the Android-specific plugin implementation
    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Android 13+ (API 33+) requires an explicit runtime grant for
    // POST_NOTIFICATIONS before any local notification can appear.
    await androidPlugin?.requestNotificationsPermission();

    // Create the channel up front so it exists before the first show() call.
    // On Android < 8 this is a no-op.
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Memory saves, shares, and app alerts',
        importance: Importance.high,
      ),
    );

    // Request FCM permission (required on Android 13+ and iOS)
    await FirebaseMessaging.instance.requestPermission();

    // Display FCM messages that arrive while the app is in the foreground
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      showLocalNotification(
        title: notification.title ?? 'Luma',
        body:  notification.body  ?? '',
      );
    });
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Memory saves, shares, and app alerts',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      ),
    );
    await _local.show(id, title, body, details);
  }

  static Future<String?> getFcmToken() =>
      FirebaseMessaging.instance.getToken();
}
