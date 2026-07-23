import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/models.dart';
import '../../services/play_session_notifications.dart';
import 'dashboard_screen.dart';

class PlayTrackerScreen extends ConsumerWidget {
  const PlayTrackerScreen({super.key});

  static const _groupOrder = [
    'food',
    'full time',
    'MORE TROOPS',
    'my new boys',
    'None',
    'ore',
    'SMALL HYPERS',
    'stone',
    'wood',
    'Other',
  ];

  static const _accountOrder = [
    'Ngguggeewr',
    'Fherood',
    'puniica',
    'Xsmax256',
    'NishV5',
    'Vikramann',
    'NisFOODrin',
    'NISHAD FOOD',
    'xx tenpo xx',
    'CH4RLIEEE',
    'Newbieme2',
    'NishadV6',
    'ZenitsuN',
    'KatzenmamaMM',
    'xxx Sanji xx',
    'NishadK',
    'IISUNNYII',
    'Nahishad1124',
    'iiikkruuuuii',
    'ID.B36491193',
    'ID.B36529234',
    'get lost A1U',
    'leonidas9x6',
    'mini b9y',
    'ImRice',
    'ImGrain',
    'ImWheat',
    'Kahigg4b',
    'Vabugbu',
    'PacifstaIII',
    'LatT6',
    'MYSANJIS',
    'Bogan3V',
    'Trnfer11',
    'NISHXX1X',
    'NISHX1SX',
    'KAIZH',
    'Maverickiy',
    'VeIWOODex',
    'NizWoodvin',
    'hype nis',
    'MYNAMIS',
  ];

  static const _fallbackGroups = {'NishadK': 'MORE TROOPS'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now().toUtc();
    final accounts =
        ref
            .watch(accountsProvider)
            .where((account) => !account.isArchived)
            .toList()
          ..sort((a, b) {
            final left = _accountOrder.indexOf(a.name);
            final right = _accountOrder.indexOf(b.name);
            return (left < 0 ? 9999 : left).compareTo(right < 0 ? 9999 : right);
          });
    final grouped = <String, List<GameAccount>>{};
    for (final account in accounts) {
      grouped.putIfAbsent(_groupFor(account), () => []).add(account);
    }
    final played = accounts
        .where((account) => account.playStatus(now) == PlayStatus.recent)
        .length;
    final due = accounts.length - played;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Play Tracker'),
        actions: [
          IconButton(
            tooltip: 'Recent activity',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => const _RecentActivitySheet(),
            ),
            icon: const Icon(Icons.manage_history_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(accountsProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(accountsProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1050),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _AccountRefreshPulse(),
                        Text(
                          'Account login checklist',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Confirm each account after you log in and play. Check-ins reset after 24 hours.',
                          style: TextStyle(color: Colors.white54),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _TrackerSummary(
                                label: 'PLAYED',
                                value: played,
                                color: AppColors.cyan,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TrackerSummary(
                                label: 'NEEDS LOGIN',
                                value: due,
                                color: AppColors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: accounts.isEmpty
                                ? null
                                : () => _startHandsFreeSession(
                                    context,
                                    ref,
                                    accounts,
                                    now,
                                  ),
                            icon: const Icon(
                              Icons.notifications_active_rounded,
                            ),
                            label: const Text(
                              'Start notification play session',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            for (final group in _groupOrder)
              if (grouped[group]?.isNotEmpty ?? false) ...[
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1050),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                        child: Text(
                          group == 'None' ? 'UNGROUPED' : group.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: grouped[group]!.length,
                  itemBuilder: (context, index) => Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1050),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                        child: _PlayAccountTile(
                          account: grouped[group]![index],
                          now: now,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  static String _groupFor(GameAccount account) {
    final marker = 'Imported account group: ';
    if (account.notes.startsWith(marker)) {
      return account.notes.substring(marker.length).split(' • ').first;
    }
    return _fallbackGroups[account.name] ?? 'Other';
  }

  static Future<void> _startHandsFreeSession(
    BuildContext context,
    WidgetRef ref,
    List<GameAccount> accounts,
    DateTime now,
  ) async {
    final due = accounts
        .where((account) => account.playStatus(now) != PlayStatus.recent)
        .toList();
    final queue = due.isEmpty ? accounts : due;
    try {
      final session = await ref
          .read(accountsRepositoryProvider)
          .startPlaySession(queue.map((account) => account.id).toList());
      await PlaySessionNotifications.initialize();
      await PlaySessionNotifications.show(session);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Play session started with ${queue.length} accounts. Use the notification controls.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start play session: $error')),
      );
    }
  }
}

class _RecentActivitySheet extends ConsumerStatefulWidget {
  const _RecentActivitySheet();

  @override
  ConsumerState<_RecentActivitySheet> createState() =>
      _RecentActivitySheetState();
}

class _RecentActivitySheetState extends ConsumerState<_RecentActivitySheet> {
  late Future<List<AccountCheckIn>> _activity;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _activity = ref.read(accountsRepositoryProvider).fetchRecentCheckIns();
  }

  Future<void> _undo(AccountCheckIn item) async {
    if (!await confirm(context, 'Undo ${item.accountName} check-in?')) return;
    await ref.read(accountsRepositoryProvider).undoCheckIn(item.id);
    await ref.read(accountsProvider.notifier).refresh();
    if (mounted) setState(_reload);
  }

  Future<void> _reassign(AccountCheckIn item) async {
    final accounts = ref.read(accountsProvider);
    var selected = item.accountId;
    final target = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change account'),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Played account'),
            items: [
              for (final account in accounts)
                DropdownMenuItem(value: account.id, child: Text(account.name)),
            ],
            onChanged: (value) =>
                setDialogState(() => selected = value ?? selected),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
    if (target == null || target == item.accountId) return;
    await ref.read(accountsRepositoryProvider).reassignCheckIn(item.id, target);
    await ref.read(accountsProvider.notifier).refresh();
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Recent play activity',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'Undo a check-in or move it to the account you actually played.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (value) =>
                  setState(() => _query = value.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search accounts',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<AccountCheckIn>>(
                future: _activity,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('${snapshot.error}'));
                  }
                  final items = (snapshot.data ?? [])
                      .where(
                        (item) =>
                            item.accountName.toLowerCase().contains(_query),
                      )
                      .toList();
                  if (items.isEmpty) {
                    return const Center(child: Text('No recent check-ins.'));
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.check_rounded),
                        ),
                        title: Text(item.accountName),
                        subtitle: Text(
                          DateFormat(
                            'MMM d, yyyy • h:mm:ss a',
                          ).format(item.playedAt.toLocal()),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'undo') _undo(item);
                            if (value == 'change') _reassign(item);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'change',
                              child: Text('Change account'),
                            ),
                            PopupMenuItem(
                              value: 'undo',
                              child: Text('Undo check-in'),
                            ),
                          ],
                        ),
                      );
                    },
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

class _AccountRefreshPulse extends ConsumerStatefulWidget {
  const _AccountRefreshPulse();

  @override
  ConsumerState<_AccountRefreshPulse> createState() =>
      _AccountRefreshPulseState();
}

class _AccountRefreshPulseState extends ConsumerState<_AccountRefreshPulse> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || ref.read(accountsLoadingProvider)) return;
      ref.read(accountsProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _TrackerSummary extends StatelessWidget {
  const _TrackerSummary({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(Icons.sports_esports_rounded, color: color),
          const SizedBox(width: 12),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PlayAccountTile extends ConsumerWidget {
  const _PlayAccountTile({required this.account, required this.now});
  final GameAccount account;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final played = account.playStatus(now) == PlayStatus.recent;
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: (played ? AppColors.cyan : AppColors.red)
                    .withValues(alpha: .13),
                child: Icon(
                  played ? Icons.check_rounded : Icons.schedule_rounded,
                  color: played ? AppColors.cyan : AppColors.red,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      account.lastPlayedAt == null
                          ? 'Never confirmed'
                          : 'Last played ${DateFormat('MMM d • h:mm a').format(account.lastPlayedAt!.toLocal())}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (constraints.maxWidth < 520)
                IconButton.filledTonal(
                  tooltip: played ? 'Played again' : 'Mark played',
                  onPressed: () => checkInAccount(context, ref, account),
                  icon: Icon(
                    played
                        ? Icons.replay_rounded
                        : Icons.check_circle_outline_rounded,
                  ),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: () => checkInAccount(context, ref, account),
                  icon: Icon(
                    played
                        ? Icons.replay_rounded
                        : Icons.check_circle_outline_rounded,
                  ),
                  label: Text(played ? 'Played again' : 'Mark played'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
