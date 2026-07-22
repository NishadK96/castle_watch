import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/config/notification_config.dart';
import '../data/repositories/notifications_repository.dart';
import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushActivationResult {
  const PushActivationResult({required this.enabled, required this.message});
  final bool enabled;
  final String message;
}

class PushNotificationService {
  PushNotificationService(this._repository);
  final NotificationsRepository _repository;
  final _local = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool _active = false;
  ValueChanged<RemoteMessage>? _onForeground;
  ValueChanged<String?>? _onTap;

  static Future<void> initializeFirebase() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
  }

  Future<PushActivationResult> activate({
    ValueChanged<RemoteMessage>? onForeground,
    ValueChanged<String?>? onTap,
  }) async {
    _onForeground = onForeground;
    _onTap = onTap;
    if (_active) {
      return const PushActivationResult(
        enabled: true,
        message: 'Push notifications are active.',
      );
    }
    if (kIsWeb && !NotificationConfig.hasWebVapidKey) {
      return const PushActivationResult(
        enabled: false,
        message: 'WEB_VAPID_KEY is missing from the build configuration.',
      );
    }

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return const PushActivationResult(
        enabled: false,
        message:
            'Notification permission was denied. Enable it in system or browser settings.',
      );
    }
    await _initializeLocalNotifications();
    await _waitForApnsIfNeeded();
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: kIsWeb ? NotificationConfig.webVapidKey : null,
    );
    if (token == null) {
      return const PushActivationResult(
        enabled: false,
        message: 'Firebase did not return a device token.',
      );
    }
    await _register(token);

    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      _register,
    );
    _messageSubscription = FirebaseMessaging.onMessage.listen((message) async {
      _onForeground?.call(message);
      await _showLocal(message);
    });
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _onTap?.call(message.data['account_id'] as String?),
    );
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _onTap?.call(initial.data['account_id'] as String?);
    }
    _active = true;
    return const PushActivationResult(
      enabled: true,
      message: 'This device is registered for push reminders.',
    );
  }

  Future<void> deactivate() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
    _tokenSubscription = null;
    _messageSubscription = null;
    _openedSubscription = null;
    _active = false;
  }

  Future<void> _initializeLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const apple = DarwinInitializationSettings();
    await _local.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: apple,
        web: WebInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _onTap?.call(response.payload),
    );
    const channel = AndroidNotificationChannel(
      'shield_reminders',
      'Shield reminders',
      description: 'Alerts before a monitored shield expires.',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> _showLocal(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _local.show(
      id: notification.hashCode,
      title: notification.title ?? 'Castle Watch',
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'shield_reminders',
          'Shield reminders',
          channelDescription: 'Alerts before a monitored shield expires.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        web: WebNotificationDetails(),
      ),
      payload: message.data['account_id'] as String?,
    );
  }

  Future<void> _register(String token) => _repository.registerDevice(
    token: token,
    platform: kIsWeb
        ? 'web'
        : defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android',
    deviceName: kIsWeb ? 'Web browser' : defaultTargetPlatform.name,
  );

  Future<void> _waitForApnsIfNeeded() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    for (var attempt = 0; attempt < 10; attempt++) {
      if (await FirebaseMessaging.instance.getAPNSToken() != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }
}
