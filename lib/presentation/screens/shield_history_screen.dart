import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/app_state.dart';
import '../../domain/models/models.dart';
import 'dashboard_screen.dart';

class ShieldHistoryScreen extends ConsumerStatefulWidget {
  const ShieldHistoryScreen({super.key});

  @override
  ConsumerState<ShieldHistoryScreen> createState() =>
      _ShieldHistoryScreenState();
}

class _ShieldHistoryScreenState extends ConsumerState<ShieldHistoryScreen> {
  String status = 'all';
  String accountId = 'all';

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(shieldHistoryProvider);
    final accounts = ref.watch(accountsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shield history'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(shieldHistoryProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: accountId,
                        decoration: const InputDecoration(labelText: 'Account'),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All accounts'),
                          ),
                          for (final account in accounts)
                            DropdownMenuItem(
                              value: account.id,
                              child: Text(account.name),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => accountId = value ?? 'all'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'expired',
                            child: Text('Expired'),
                          ),
                          DropdownMenuItem(
                            value: 'cancelled',
                            child: Text('Cancelled'),
                          ),
                          DropdownMenuItem(
                            value: 'replaced',
                            child: Text('Replaced'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => status = value ?? 'all'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: history.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _HistoryMessage(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load shield history',
                    detail: '$error',
                    action: () =>
                        ref.read(shieldHistoryProvider.notifier).refresh(),
                  ),
                  data: (items) {
                    final visible = items.where((entry) {
                      final accountMatches =
                          accountId == 'all' ||
                          entry.shield.accountId == accountId;
                      final statusMatches =
                          status == 'all' || entry.shield.status == status;
                      return accountMatches && statusMatches;
                    }).toList();
                    if (visible.isEmpty) {
                      return const _HistoryMessage(
                        icon: Icons.history_toggle_off_rounded,
                        title: 'No shield history yet',
                        detail:
                            'Shield changes will appear here after you add, renew, or cancel one.',
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () =>
                          ref.read(shieldHistoryProvider.notifier).refresh(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, index) =>
                            _HistoryCard(entry: visible[index]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.entry});
  final ShieldHistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shield = entry.shield;
    final now = DateTime.now().toUtc();
    final state = shield.state(now);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: statusColor(state).withValues(alpha: .15),
          child: Icon(Icons.shield_rounded, color: statusColor(state)),
        ),
        title: Text(entry.accountName),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${shield.type} • ${DateFormat('MMM d, yyyy • h:mm a').format(shield.startedAt.toLocal())}\n'
            'Expires ${DateFormat('MMM d, yyyy • h:mm a').format(shield.expiresAt.toLocal())}',
          ),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'delete' &&
                await confirm(context, 'Delete this history entry?')) {
              await ref.read(shieldHistoryProvider.notifier).delete(shield.id);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
          icon: const Icon(Icons.more_vert_rounded),
        ),
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: Colors.white30),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54),
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            FilledButton.tonal(
              onPressed: action,
              child: const Text('Try again'),
            ),
          ],
        ],
      ),
    ),
  );
}
