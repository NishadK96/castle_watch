import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/config/supabase_config.dart';
import 'services/push_notification_service.dart';
import 'services/play_session_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.initializeFirebase();
  await SupabaseConfig.initialize();
  await PlaySessionNotifications.initialize();
  runApp(const ProviderScope(child: CastleWatchApp()));
}
