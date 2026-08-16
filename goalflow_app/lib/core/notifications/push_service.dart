import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Firebase Cloud Messaging wiring for Android and iOS.
///
/// The app only asks for permission, registers its device token with our backend
/// and renders/handles messages. WHAT gets sent and WHEN is decided entirely by
/// the server from the user's saved preferences -- there is no notification
/// logic in the UI.
///
/// Every path is wrapped so that a missing `google-services.json` /
/// `GoogleService-Info.plist` degrades to "no push" rather than a crash on
/// launch.

/// Must be a top-level function: the OS spawns a separate Dart isolate for
/// background messages, so it cannot reach anything captured in a closure.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // The system tray already renders the notification payload while the app is
  // backgrounded; this exists so data-only messages are not dropped.
  debugPrint('Background message: ${message.messageId}');
}

class PushService {
  PushService(this._registerToken, {this.onOpenRoute});

  final Future<void> Function(String token, String platform) _registerToken;

  /// Called with a route when a notification is tapped, so the app can navigate.
  final void Function(String route)? onOpenRoute;

  final _local = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'goalflow_default',
    'GoalFlow reminders',
    description: 'Action reminders, milestones and weekly summaries',
    importance: Importance.high,
  );

  static String get _platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  Future<void> init() async {
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Notifications denied by the user');
        return;
      }

      await _initLocal();

      // iOS shows nothing in the foreground unless explicitly told to. Without
      // this a reminder that arrives while the app is open is silently lost.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      await _syncToken(messaging);

      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);

      // The app may have been launched *from* a notification while terminated.
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleOpen(initial);
    } catch (e) {
      debugPrint('Push unavailable: $e');
    }
  }

  Future<void> _initLocal() async {
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          final route = data['route']?.toString();
          if (route != null) onOpenRoute?.call(route);
        } catch (_) {
          // A malformed payload should open the app, not crash it.
        }
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Android 13+ gates notifications behind a runtime permission.
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _syncToken(FirebaseMessaging messaging) async {
    // On iOS the FCM token only exists once APNs has handed one over.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final apns = await messaging.getAPNSToken();
      if (apns == null) {
        debugPrint('APNs token not ready yet - push will register on refresh');
      }
    }

    final token = await messaging.getToken();
    if (token != null) await _registerToken(token, _platform);

    // Tokens rotate; the backend prunes stale ones when a send fails.
    messaging.onTokenRefresh.listen((t) => _registerToken(t, _platform));
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
          // Long text so a full greeting is readable without expanding.
          styleInformation: BigTextStyleInformation(n.body ?? ''),
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleOpen(RemoteMessage message) {
    final route = message.data['route']?.toString();
    if (route != null && route.isNotEmpty) onOpenRoute?.call(route);
  }
}
