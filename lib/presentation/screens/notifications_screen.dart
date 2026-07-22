import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../application/app_state.dart';
import '../../application/notifications_state.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/notification_models.dart';

class NotificationHistoryScreen extends ConsumerWidget {
  const NotificationHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(notificationLogsProvider);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(notificationLogsProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifications',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Delivery history across your castles',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => ref.invalidate(notificationLogsProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),
            ),
            logs.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                child: _NotificationEmpty(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load notifications',
                  message: error.toString(),
                  action: () => ref.invalidate(notificationLogsProvider),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const SliverFillRemaining(
                      child: _NotificationEmpty(
                        icon: Icons.notifications_none_rounded,
                        title: 'No alerts yet',
                        message:
                            'Shield reminders and their delivery status will appear here.',
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, index) =>
                            _NotificationTile(log: items[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.log});
  final NotificationLog log;
  @override
  Widget build(BuildContext context) {
    final delivered = log.status == 'sent';
    final color = delivered
        ? AppColors.cyan
        : log.status == 'pending'
        ? AppColors.amber
        : AppColors.red;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                delivered
                    ? Icons.notifications_active_rounded
                    : Icons.notification_important_outlined,
                color: color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          log.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        DateFormat(
                          'MMM d, h:mm a',
                        ).format(log.sentAt ?? log.createdAt),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(log.body, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 10),
                  Text(
                    log.status.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(notificationPreferencesProvider);
    final devices = ref.watch(activeDeviceCountProvider);
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
          vertical: 24,
        ),
        children: [
          Text(
            'Settings',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'Profile, delivery devices and reminder schedule',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('PROFILE'),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(
                SupabaseConfig.isConfigured
                    ? SupabaseConfig.client.auth.currentUser?.email ??
                          'Commander'
                    : 'Demo commander',
              ),
              subtitle: const Text('Timezone · Device local time'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('DELIVERY'),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              leading: const Icon(Icons.devices_rounded, color: AppColors.cyan),
              title: Text(
                devices.when(
                  data: (count) =>
                      '$count active ${count == 1 ? 'device' : 'devices'}',
                  loading: () => 'Checking devices…',
                  error: (_, _) => 'Device status unavailable',
                ),
              ),
              subtitle: Text(
                devices.value == 0
                    ? 'Firebase device registration is required before push reminders can arrive.'
                    : 'This device can receive server-scheduled reminders.',
              ),
              trailing: const Icon(Icons.info_outline_rounded),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('PUSH REMINDERS'),
          const SizedBox(height: 10),
          preferences.when(
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (error, _) => Card(
              child: ListTile(
                title: const Text('Could not load preferences'),
                subtitle: Text(error.toString()),
                trailing: IconButton(
                  onPressed: () =>
                      ref.invalidate(notificationPreferencesProvider),
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ),
            data: (value) => _PreferencesCard(
              value: value,
              onChange: (next) => ref
                  .read(notificationPreferencesProvider.notifier)
                  .save((_) => next),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              if (SupabaseConfig.isConfigured) {
                await ref.read(authRepositoryProvider).signOut();
              }
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
          const SizedBox(height: 22),
          const Text(
            'Castle Watch is an independent player-support tool and is not affiliated with Lords Mobile or its publisher.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({required this.value, required this.onChange});
  final NotificationPreferences value;
  final ValueChanged<NotificationPreferences> onChange;
  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        SwitchListTile(
          value: value.pushEnabled,
          onChanged: (enabled) =>
              onChange(value.copyWith(pushEnabled: enabled)),
          title: const Text('Push notifications'),
          subtitle: const Text('Master notification control'),
          secondary: const Icon(Icons.notifications_active_outlined),
        ),
        const Divider(height: 1),
        _switch(
          '24 hours before',
          value.reminder24h,
          (enabled) => value.copyWith(reminder24h: enabled),
        ),
        _switch(
          '6 hours before',
          value.reminder6h,
          (enabled) => value.copyWith(reminder6h: enabled),
        ),
        _switch(
          '1 hour before',
          value.reminder1h,
          (enabled) => value.copyWith(reminder1h: enabled),
        ),
        _switch(
          '15 minutes before',
          value.reminder15m,
          (enabled) => value.copyWith(reminder15m: enabled),
        ),
        _switch(
          'At expiration',
          value.reminderExpired,
          (enabled) => value.copyWith(reminderExpired: enabled),
        ),
      ],
    ),
  );
  Widget _switch(
    String title,
    bool enabled,
    NotificationPreferences Function(bool) change,
  ) => SwitchListTile(
    value: enabled,
    onChanged: value.pushEnabled ? (next) => onChange(change(next)) : null,
    title: Text(title),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Colors.white54,
      letterSpacing: 1.4,
      fontWeight: FontWeight.w700,
      fontSize: 12,
    ),
  );
}

class _NotificationEmpty extends StatelessWidget {
  const _NotificationEmpty({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title, message;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white30, size: 58),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: action,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    ),
  );
}
