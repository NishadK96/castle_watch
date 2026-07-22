import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../application/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/models.dart';

enum DashboardFilter { all, shielded, expiring, expired, noShield, favorites }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashboardFilter filter = DashboardFilter.all;
  String query = '';
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final pagePadding = isMobile ? 16.0 : 24.0;
    final accounts = ref
        .watch(accountsProvider)
        .where((a) => !a.isArchived)
        .toList();
    final loading = ref.watch(accountsLoadingProvider);
    final loadError = ref.watch(accountErrorProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now().toUtc();
    final visible =
        accounts.where((a) {
          final q = query.toLowerCase();
          final matches = '${a.name} ${a.playerName} ${a.guild} ${a.kingdom}'
              .toLowerCase()
              .contains(q);
          final state = a.shield?.state(now) ?? ShieldState.none;
          final filtered = switch (filter) {
            DashboardFilter.all => true,
            DashboardFilter.shielded =>
              state != ShieldState.none && state != ShieldState.expired,
            DashboardFilter.expiring => {
              ShieldState.attention,
              ShieldState.warning,
              ShieldState.critical,
            }.contains(state),
            DashboardFilter.expired => state == ShieldState.expired,
            DashboardFilter.noShield => state == ShieldState.none,
            DashboardFilter.favorites => a.isFavorite,
          };
          return matches && filtered;
        }).toList()..sort(
          (a, b) => (a.shield?.expiresAt ?? DateTime(9999)).compareTo(
            b.shield?.expiresAt ?? DateTime(9999),
          ),
        );
    final shielded = accounts
        .where((a) => a.shield != null && a.shield!.expiresAt.isAfter(now))
        .length;
    final expiring = accounts
        .where(
          (a) => {
            ShieldState.attention,
            ShieldState.warning,
            ShieldState.critical,
          }.contains(a.shield?.state(now)),
        )
        .length;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-.85, -1.1),
          radius: 1.15,
          colors: [Color(0x1F3978A8), AppColors.background],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                pagePadding,
                isMobile ? 14 : 28,
                pagePadding,
                0,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _Header(onAdd: () => showAccountForm(context, ref)),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                  if (loadError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: MaterialBanner(
                        content: Text(loadError),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                ref.read(accountsProvider.notifier).refresh(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: isMobile ? 18 : 24),
                  LayoutBuilder(
                    builder: (_, box) {
                      final width = box.maxWidth;
                      final columns = width > 1050 ? 4 : 2;
                      return GridView.count(
                        crossAxisCount: columns,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: isMobile ? 10 : 12,
                        mainAxisSpacing: isMobile ? 10 : 12,
                        childAspectRatio: isMobile ? 1.18 : 2.15,
                        children: [
                          SummaryCard(
                            label: 'TOTAL ACCOUNTS',
                            value: '${accounts.length}',
                            icon: Icons.castle_outlined,
                            color: AppColors.blue,
                          ),
                          SummaryCard(
                            label: 'SHIELDED',
                            value: '$shielded',
                            icon: Icons.shield_rounded,
                            color: AppColors.cyan,
                          ),
                          SummaryCard(
                            label: 'EXPIRING SOON',
                            value: '$expiring',
                            icon: Icons.timer_outlined,
                            color: AppColors.amber,
                          ),
                          SummaryCard(
                            label: 'UNSHIELDED',
                            value: '${accounts.length - shielded}',
                            icon: Icons.gpp_bad_outlined,
                            color: AppColors.red,
                          ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: isMobile ? 24 : 30),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your castles',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '${visible.length} ${visible.length == 1 ? 'account' : 'accounts'}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search accounts, guilds or kingdoms',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: DashboardFilter.values
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                selected: filter == item,
                                onSelected: (_) =>
                                    setState(() => filter = item),
                                label: Text(_filterName(item)),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
            if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _Empty(onAdd: () => showAccountForm(context, ref)),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  pagePadding,
                  0,
                  pagePadding,
                  isMobile ? 92 : 48,
                ),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => AccountCard(account: visible[i], now: now),
                    childCount: visible.length,
                  ),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: isMobile ? 600 : 520,
                    mainAxisExtent: isMobile ? 286 : 292,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _filterName(DashboardFilter value) => switch (value) {
    DashboardFilter.all => 'All',
    DashboardFilter.shielded => 'Shielded',
    DashboardFilter.expiring => 'Expiring soon',
    DashboardFilter.expired => 'Expired',
    DashboardFilter.noShield => 'No shield',
    DashboardFilter.favorites => 'Favorites',
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: mobile ? 38 : 44,
              height: mobile ? 38 : 44,
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: AppColors.cyan.withValues(alpha: .25),
                ),
              ),
              child: const Icon(Icons.shield_rounded, color: AppColors.cyan),
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Text(
                'CASTLE WATCH',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            IconButton.filledTonal(
              onPressed: () {},
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ],
        ),
        SizedBox(height: mobile ? 22 : 28),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mobile ? 'Command center' : 'Good evening, Commander',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Keep every castle protected.',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(mobile ? 'Add' : 'Add account'),
            ),
          ],
        ),
      ],
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(mobile ? 13 : 16),
        child: mobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .35,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        value,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: .6,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class AccountCard extends ConsumerWidget {
  const AccountCard({super.key, required this.account, required this.now});
  final GameAccount account;
  final DateTime now;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shield = account.shield;
    final status = shield?.state(now) ?? ShieldState.none;
    final color = statusColor(status);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.blue, Color(0xFF945EFF)],
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.castle_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (account.playerName.isNotEmpty)
                          Text(
                            account.playerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => ref
                        .read(accountsProvider.notifier)
                        .toggleFavorite(account.id),
                    icon: Icon(
                      account.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: account.isFavorite
                          ? AppColors.amber
                          : Colors.white38,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  StatusBadge(status: status),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      [
                        account.kingdom,
                        account.guild,
                      ].where((item) => item.isNotEmpty).join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (shield != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        formatRemaining(shield.remaining(now)),
                        style: TextStyle(
                          fontSize: 27,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          shield.type.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                        Text(
                          DateFormat(
                            'MMM d • h:mm a',
                          ).format(shield.expiresAt.toLocal()),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                LinearProgressIndicator(
                  value: _progress(shield, now),
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(8),
                  color: color,
                  backgroundColor: color.withValues(alpha: .12),
                ),
              ] else
                const Expanded(
                  child: Center(
                    child: Text(
                      'No active shield',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => showShieldSheet(context, ref, account),
                  icon: Icon(
                    shield == null
                        ? Icons.add_moderator_outlined
                        : Icons.refresh_rounded,
                  ),
                  label: Text(shield == null ? 'Add shield' : 'Renew shield'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _progress(Shield s, DateTime now) {
    final total = s.expiresAt.difference(s.startedAt).inSeconds;
    return total <= 0 ? 0 : (s.remaining(now).inSeconds / total).clamp(0, 1);
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final ShieldState status;
  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    final label = switch (status) {
      ShieldState.safe => 'SAFE',
      ShieldState.attention => 'ATTENTION',
      ShieldState.warning => 'WARNING',
      ShieldState.critical => 'CRITICAL',
      ShieldState.expired => 'EXPIRED',
      ShieldState.none => 'NO SHIELD',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: .3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status == ShieldState.none
                ? Icons.shield_outlined
                : Icons.shield_rounded,
            color: c,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

Color statusColor(ShieldState status) => switch (status) {
  ShieldState.safe => AppColors.cyan,
  ShieldState.attention => AppColors.amber,
  ShieldState.warning => Colors.orange,
  ShieldState.critical ||
  ShieldState.expired ||
  ShieldState.none => AppColors.red,
};
String formatRemaining(Duration d) {
  if (d <= Duration.zero) return 'Expired';
  final days = d.inDays,
      hours = d.inHours.remainder(24),
      mins = d.inMinutes.remainder(60),
      secs = d.inSeconds.remainder(60);
  if (days > 0) {
    return '${days}d ${hours.toString().padLeft(2, '0')}h ${mins.toString().padLeft(2, '0')}m';
  }
  if (d.inHours > 0) return '${d.inHours}h ${mins.toString().padLeft(2, '0')}m';
  return '${d.inMinutes}m ${secs.toString().padLeft(2, '0')}s';
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.castle_outlined, size: 60, color: Colors.white38),
        const SizedBox(height: 16),
        Text(
          'Build your command center',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('Add your first account to start tracking shields.'),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add your first account'),
        ),
      ],
    ),
  );
}

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAccountForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Account'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: accounts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final a = accounts[i];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: const CircleAvatar(child: Icon(Icons.castle_outlined)),
              title: Text(a.name),
              subtitle: Text(
                [
                  a.playerName,
                  a.kingdom,
                  a.guild,
                ].where((e) => e.isNotEmpty).join(' • '),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'favorite') {
                    ref.read(accountsProvider.notifier).toggleFavorite(a.id);
                  }
                  if (v == 'archive') {
                    ref.read(accountsProvider.notifier).archive(a.id);
                  }
                  if (v == 'delete' &&
                      await confirm(context, 'Delete ${a.name}?')) {
                    ref.read(accountsProvider.notifier).delete(a.id);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'favorite',
                    child: Text(a.isFavorite ? 'Remove favorite' : 'Favorite'),
                  ),
                  const PopupMenuItem(value: 'archive', child: Text('Archive')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<void> showAccountForm(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController(),
      player = TextEditingController(),
      kingdom = TextEditingController(),
      guild = TextEditingController();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(ctx).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add account', style: Theme.of(ctx).textTheme.headlineSmall),
          const SizedBox(height: 18),
          TextField(
            controller: name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Account name *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: player,
            decoration: const InputDecoration(labelText: 'Player name'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: kingdom,
                  decoration: const InputDecoration(labelText: 'Kingdom'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: guild,
                  decoration: const InputDecoration(labelText: 'Guild'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              ref
                  .read(accountsProvider.notifier)
                  .addAccount(
                    name: name.text.trim(),
                    player: player.text.trim(),
                    kingdom: kingdom.text.trim(),
                    guild: guild.text.trim(),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Add account'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  player.dispose();
  kingdom.dispose();
  guild.dispose();
}

Future<void> showShieldSheet(
  BuildContext context,
  WidgetRef ref,
  GameAccount account,
) async {
  const options = [
    ('4 hours', Duration(hours: 4)),
    ('8 hours', Duration(hours: 8)),
    ('24 hours', Duration(hours: 24)),
    ('3 days', Duration(days: 3)),
    ('7 days', Duration(days: 7)),
    ('14 days', Duration(days: 14)),
  ];
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${account.shield == null ? 'Add' : 'Renew'} shield',
            style: Theme.of(ctx).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(account.name, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final o in options)
                ActionChip(
                  label: Text(o.$1),
                  avatar: const Icon(Icons.shield_outlined, size: 18),
                  onPressed: () async {
                    if (account.shield != null &&
                        !await confirm(ctx, 'Replace the current shield?')) {
                      return;
                    }
                    ref
                        .read(accountsProvider.notifier)
                        .addShield(account.id, o.$2);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<bool> confirm(BuildContext context, String title) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;
