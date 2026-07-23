import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../domain/models/models.dart';

const _notificationId = 91042;
final _notifications = FlutterLocalNotificationsPlugin();
bool _pickerRequested = false;

@pragma('vm:entry-point')
Future<void> playSessionNotificationResponse(
  NotificationResponse response,
) async {
  if (response.actionId == 'castle_watch_choose_account_v1') {
    _pickerRequested = true;
    return;
  }
  final action = switch (response.actionId) {
    _ => null,
  };
  if (action == null || response.payload == null) return;
  final payload = jsonDecode(response.payload!) as Map<String, dynamic>;
  final client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
  final result = await client.rpc(
    'advance_play_session',
    params: {
      'p_session_id': payload['id'],
      'p_secret': payload['secret'],
      'p_action': action,
    },
  );
  final row = Map<String, dynamic>.from(result as Map);
  if (row['status'] == 'active') {
    await _showNative(PlaySession.fromJson(row));
  } else {
    await _notifications.cancel(id: _notificationId);
  }
  client.dispose();
}

Future<void> _configure() => _notifications.initialize(
  settings: const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  ),
  onDidReceiveBackgroundNotificationResponse: playSessionNotificationResponse,
  onDidReceiveNotificationResponse: playSessionNotificationResponse,
);

Future<void> _showNative(PlaySession session) => _notifications.show(
  id: _notificationId,
  title: 'Castle Watch quick check-in',
  body: 'Tap Choose account after playing any account.',
  notificationDetails: const NotificationDetails(
    android: AndroidNotificationDetails(
      'play_session',
      'Play session',
      channelDescription: 'Account-by-account login checklist.',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      actions: [
        AndroidNotificationAction(
          'castle_watch_choose_account_v1',
          'Choose account',
          cancelNotification: false,
          showsUserInterface: true,
        ),
      ],
    ),
  ),
  payload: jsonEncode({'id': session.id, 'secret': session.secret}),
);

abstract final class PlaySessionNotifications {
  static Future<void> initialize() => _configure();
  static bool consumePickerRequest() {
    final requested = _pickerRequested;
    _pickerRequested = false;
    return requested;
  }

  static Future<void> show(PlaySession session) => _showNative(session);
}
