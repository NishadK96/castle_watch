import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const demoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: false,
  );
  static bool get hasValues => url.isNotEmpty && anonKey.isNotEmpty;
  static bool get hasPlaceholderUrl =>
      url.contains('abcdefghijk') ||
      url.contains('YOUR_PROJECT_REF') ||
      url.contains('your-project');
  static bool get isConfigured => hasValues && !hasPlaceholderUrl;

  static Future<void> initialize() async {
    if (!isConfigured) return;
    await Supabase.initialize(url: url, publishableKey: anonKey);
  }

  static SupabaseClient get client {
    if (!isConfigured) throw StateError('Supabase is not configured.');
    return Supabase.instance.client;
  }
}
