import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Firebase Cloud Messaging wiring.
///
/// The app only asks for permission, registers its device token with our backend
/// and renders foreground messages. WHAT gets sent and WHEN is decided entirely
/// by the server from the user's saved preferences -- there is no notification
/// logic in the UI.
class PushService {
  PushService(this._registerToken);

  final Future<void> Function(String token, String platform) _registerToken;

  final _local = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'goalflow_default',
    'GoalFlow reminders',
    description: 'Action reminders, milestones and weekly summaries',
    importance: Importance.high,
  );

  Future<void> init() async {
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      final token = await messaging.getToken();
      if (token != null) {
        await _registerToken(token, defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
      }
      // Tokens rotate; the backend prunes stale ones on send.
      messaging.onTokenRefresh.listen((t) => _registerToken(
            t,
            defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
          ));

      FirebaseMessaging.onMessage.listen(_showForeground);
    } catch (e) {
      // A missing google-services.json must never block the app from running.
      debugPrint('Push unavailable: $e');
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    await _local.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
