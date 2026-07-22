import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_failure.dart';
import '../../domain/models/notification_models.dart';

class NotificationsRepository {
  SupabaseClient get _client => SupabaseConfig.client;
  String get _userId => _client.auth.currentUser!.id;

  Future<NotificationPreferences> fetchPreferences() async {
    try {
      final row = await _client
          .from('notification_preferences')
          .select()
          .eq('user_id', _userId)
          .maybeSingle();
      if (row != null) return NotificationPreferences.fromJson(row);
      final created = await _client
          .from('notification_preferences')
          .insert({'user_id': _userId})
          .select()
          .single();
      return NotificationPreferences.fromJson(created);
    } catch (error) {
      throw AppFailure.friendly(error);
    }
  }

  Future<NotificationPreferences> savePreferences(
    NotificationPreferences value,
  ) async {
    try {
      final row = await _client
          .from('notification_preferences')
          .update(value.toJson())
          .eq('user_id', _userId)
          .select()
          .single();
      return NotificationPreferences.fromJson(row);
    } catch (error) {
      throw AppFailure.friendly(error);
    }
  }

  Future<List<NotificationLog>> fetchLogs() async {
    try {
      final rows = await _client
          .from('notification_logs')
          .select()
          .eq('user_id', _userId)
          .order('created_at', ascending: false)
          .limit(100);
      return rows.map(NotificationLog.fromJson).toList();
    } catch (error) {
      throw AppFailure.friendly(error);
    }
  }

  Future<int> activeDeviceCount() async {
    try {
      return await _client
          .from('user_devices')
          .count(CountOption.exact)
          .eq('user_id', _userId)
          .eq('is_active', true);
    } catch (error) {
      throw AppFailure.friendly(error);
    }
  }

  Future<void> registerDevice({
    required String token,
    required String platform,
    String? deviceName,
  }) async {
    try {
      await _client.from('user_devices').upsert({
        'user_id': _userId,
        'device_token': token,
        'platform': platform,
        'device_name': deviceName,
        'is_active': true,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'device_token');
    } catch (error) {
      throw AppFailure.friendly(error);
    }
  }
}
