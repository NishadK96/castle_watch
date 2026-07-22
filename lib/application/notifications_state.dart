import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/supabase_config.dart';
import '../data/repositories/notifications_repository.dart';
import '../domain/models/notification_models.dart';
import '../services/push_notification_service.dart';

final notificationsRepositoryProvider = Provider(
  (ref) => NotificationsRepository(),
);
final pushNotificationServiceProvider = Provider(
  (ref) => PushNotificationService(ref.read(notificationsRepositoryProvider)),
);
final notificationPreferencesProvider =
    AsyncNotifierProvider<
      NotificationPreferencesNotifier,
      NotificationPreferences
    >(NotificationPreferencesNotifier.new);
final notificationLogsProvider =
    AsyncNotifierProvider<NotificationLogsNotifier, List<NotificationLog>>(
      NotificationLogsNotifier.new,
    );
final activeDeviceCountProvider = FutureProvider<int>((ref) async {
  if (!SupabaseConfig.isConfigured) return 0;
  return ref.read(notificationsRepositoryProvider).activeDeviceCount();
});

class NotificationPreferencesNotifier
    extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() async {
    if (!SupabaseConfig.isConfigured) return const NotificationPreferences();
    return ref.read(notificationsRepositoryProvider).fetchPreferences();
  }

  Future<void> save(
    NotificationPreferences Function(NotificationPreferences) change,
  ) async {
    final current = state.value ?? const NotificationPreferences();
    final next = change(current);
    state = AsyncData(next);
    if (!SupabaseConfig.isConfigured) return;
    state = await AsyncValue.guard(
      () => ref.read(notificationsRepositoryProvider).savePreferences(next),
    );
  }
}

class NotificationLogsNotifier extends AsyncNotifier<List<NotificationLog>> {
  @override
  Future<List<NotificationLog>> build() async {
    if (!SupabaseConfig.isConfigured) return const [];
    return ref.read(notificationsRepositoryProvider).fetchLogs();
  }

  Future<void> refresh() async => state = await AsyncValue.guard(
    () => ref.read(notificationsRepositoryProvider).fetchLogs(),
  );
}
