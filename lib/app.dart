import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'application/app_state.dart';
import 'application/notifications_state.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/notifications_screen.dart';

final _router = GoRouter(
  initialLocation: '/dashboard',
  redirect: (context, state) {
    if (!SupabaseConfig.isConfigured) {
      if (SupabaseConfig.demoMode) return null;
      return state.matchedLocation == '/login' ? null : '/login';
    }
    final signedIn = SupabaseConfig.client.auth.currentSession != null;
    final atLogin = state.matchedLocation == '/login';
    if (!signedIn && !atLogin) return '/login';
    if (signedIn && atLogin) return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    ShellRoute(
      builder: (_, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/accounts',
          builder: (context, state) => const AccountsScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const PlaceholderScreen(
            title: 'Shield history',
            icon: Icons.history_rounded,
          ),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationHistoryScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const NotificationSettingsScreen(),
        ),
      ],
    ),
  ],
);

class CastleWatchApp extends StatelessWidget {
  const CastleWatchApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Castle Watch',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark(),
    routerConfig: _router,
  );
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;
  static const paths = [
    '/dashboard',
    '/accounts',
    '/history',
    '/notifications',
    '/settings',
  ];
  static const destinations = [
    NavigationRailDestination(
      icon: Icon(Icons.grid_view_rounded),
      label: Text('Dashboard'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.castle_outlined),
      label: Text('Accounts'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.history_rounded),
      label: Text('History'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.notifications_none_rounded),
      label: Text('Alerts'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      label: Text('Settings'),
    ),
  ];

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _activatePush());
  }

  Future<void> _activatePush() async {
    if (!SupabaseConfig.isConfigured ||
        SupabaseConfig.client.auth.currentUser == null) {
      return;
    }
    try {
      final result = await ref
          .read(pushNotificationServiceProvider)
          .activate(
            onForeground: (message) {
              if (!mounted) return;
              final notification = message.notification;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    notification?.body ?? 'A new Castle Watch alert arrived.',
                  ),
                  action: SnackBarAction(
                    label: 'View',
                    onPressed: () => context.go('/notifications'),
                  ),
                ),
              );
            },
            onTap: (_) => context.go('/dashboard'),
          );
      ref.invalidate(activeDeviceCountProvider);
      if (!result.enabled && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Push registration is unavailable. Check notification permission and configuration.',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    ref.read(pushNotificationServiceProvider).deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = AppShell.paths
        .indexWhere(widget.location.startsWith)
        .clamp(0, AppShell.paths.length - 1);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    if (!wide) {
      return Scaffold(
        body: widget.child,
        bottomNavigationBar: NavigationBar(
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          selectedIndex: index,
          onDestinationSelected: (i) => context.go(AppShell.paths[i]),
          destinations: AppShell.destinations
              .map(
                (d) => NavigationDestination(
                  icon: d.icon,
                  label: (d.label as Text).data!,
                ),
              )
              .toList(),
        ),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: (i) => context.go(AppShell.paths[i]),
            extended: MediaQuery.sizeOf(context).width >= 1160,
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 32),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shield_rounded,
                    color: AppColors.cyan,
                    size: 30,
                  ),
                  if (MediaQuery.sizeOf(context).width >= 1160)
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Text(
                        'CASTLE WATCH',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            destinations: AppShell.destinations,
          ),
          const VerticalDivider(width: 1, color: Color(0xFF202A3E)),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, required this.icon});
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: AppColors.cyan),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Your activity will appear here.'),
      ],
    ),
  );
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool push = true, h24 = true, h6 = true, h1 = true, m15 = true;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        'Settings',
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 24),
      const Text(
        'PROFILE',
        style: TextStyle(color: Colors.white54, letterSpacing: 1.5),
      ),
      const SizedBox(height: 10),
      const Card(
        child: ListTile(
          contentPadding: EdgeInsets.all(18),
          leading: CircleAvatar(child: Text('AV')),
          title: Text('Astra Vanguard'),
          subtitle: Text('UTC +05:30 · Asia/Kolkata'),
          trailing: Icon(Icons.chevron_right),
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'PUSH REMINDERS',
        style: TextStyle(color: Colors.white54, letterSpacing: 1.5),
      ),
      const SizedBox(height: 10),
      Card(
        child: Column(
          children: [
            SwitchListTile(
              value: push,
              onChanged: (v) => setState(() => push = v),
              title: const Text('Push notifications'),
              subtitle: const Text('Permission granted'),
            ),
            const Divider(height: 1),
            for (final item in [
              ('24 hours before', h24, (bool v) => h24 = v),
              ('6 hours before', h6, (bool v) => h6 = v),
              ('1 hour before', h1, (bool v) => h1 = v),
              ('15 minutes before', m15, (bool v) => m15 = v),
            ])
              SwitchListTile(
                value: item.$2,
                onChanged: push ? (v) => setState(() => item.$3(v)) : null,
                title: Text(item.$1),
              ),
          ],
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
      const SizedBox(height: 24),
      const Text(
        'Castle Watch is an independent player-support tool and is not affiliated with Lords Mobile or its publisher.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white38, fontSize: 12),
      ),
    ],
  );
}
