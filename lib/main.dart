import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/config/supabase_config.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.initializeFirebase();
  await SupabaseConfig.initialize();
  runApp(const ProviderScope(child: CastleWatchApp()));
}
