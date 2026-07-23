import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/models.dart';
import 'dashboard_screen.dart';

class AccountDetailsScreen extends ConsumerWidget {
  const AccountDetailsScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref
        .watch(accountsProvider)
        .where((a) => a.id == accountId)
        .firstOrNull;
    final loading = ref.watch(accountsLoadingProvider);
    if (account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: Center(
          child: loading
              ? const CircularProgressIndicator()
              : const Text('Account not found'),
        ),
      );
    }

    final now = ref.watch(clockProvider).value ?? DateTime.now().toUtc();
    final shield = account.shield;
    final status = shield?.state(now) ?? ShieldState.none;
    final checkIns = ref.watch(accountCheckInsProvider(account.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          IconButton(
            tooltip: account.isFavorite ? 'Remove favorite' : 'Favorite',
            onPressed: () =>
                ref.read(accountsProvider.notifier).toggleFavorite(account.id),
            icon: Icon(
              account.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: account.isFavorite ? AppColors.amber : null,
            ),
          ),
          IconButton(
            tooltip: 'Edit account',
            onPressed: () => showAccountForm(context, ref, account: account),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Wrap(
                    spacing: 28,
                    runSpacing: 20,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        child: Icon(Icons.castle_rounded, size: 30),
                      ),
                      _Fact(label: 'PLAYER', value: account.playerName),
                      _Fact(label: 'KINGDOM', value: account.kingdom),
                      _Fact(label: 'GUILD', value: account.guild),
                      _Fact(
                        label: 'MIGHT',
                        value: account.might == 0
                            ? ''
                            : NumberFormat.compact().format(account.might),
                      ),
                      _Fact(
                        label: 'CASTLE LEVEL',
                        value: account.castleLevel == 0
                            ? ''
                            : '${account.castleLevel}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Play check-in',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          PlayStatusBadge(account: account, now: now),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        account.lastPlayedAt == null
                            ? 'No play session has been confirmed yet.'
                            : 'Last played ${DateFormat('EEE, MMM d • h:mm a').format(account.lastPlayedAt!.toLocal())}',
                        style: const TextStyle(color: Colors.white60),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => checkInAccount(context, ref, account),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Mark as played now'),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Recent check-ins',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      checkIns.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, _) => Text(
                          'History unavailable: $error',
                          style: const TextStyle(color: AppColors.red),
                        ),
                        data: (items) => items.isEmpty
                            ? const Text(
                                'Your check-in history will appear here.',
                                style: TextStyle(color: Colors.white38),
                              )
                            : Column(
                                children: [
                                  for (final item in items.take(5))
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      leading: const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.cyan,
                                      ),
                                      title: Text(
                                        DateFormat(
                                          'EEE, MMM d • h:mm a',
                                        ).format(item.playedAt.toLocal()),
                                      ),
                                      subtitle: item.notes.isEmpty
                                          ? null
                                          : Text(item.notes),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Current shield',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          StatusBadge(status: status),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (shield == null)
                        const Text(
                          'No active shield. Add one to begin tracking.',
                          style: TextStyle(color: Colors.white60),
                        )
                      else ...[
                        Text(
                          formatRemaining(shield.remaining(now)),
                          style: TextStyle(
                            color: statusColor(status),
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Expires ${DateFormat('EEE, MMM d • h:mm a').format(shield.expiresAt.toLocal())}',
                          style: const TextStyle(color: Colors.white60),
                        ),
                        if (shield.notes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(shield.notes),
                        ],
                      ],
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: () =>
                                showShieldSheet(context, ref, account),
                            icon: Icon(
                              shield == null
                                  ? Icons.add_moderator_outlined
                                  : Icons.refresh_rounded,
                            ),
                            label: Text(
                              shield == null ? 'Add shield' : 'Renew shield',
                            ),
                          ),
                          if (shield != null)
                            OutlinedButton.icon(
                              onPressed: () async {
                                if (!await confirm(
                                  context,
                                  'Cancel this shield?',
                                )) {
                                  return;
                                }
                                await ref
                                    .read(accountsProvider.notifier)
                                    .cancelShield(account.id);
                              },
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Cancel shield'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (account.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account notes',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(account.notes),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 130,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value.isEmpty ? '—' : value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
