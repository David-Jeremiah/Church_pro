import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/roles.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/church_logo.dart';
import '../core/widgets/ui_kit.dart';
import 'providers.dart';

class _Dest {
  const _Dest(this.branch, this.label, this.icon, this.selectedIcon, this.permissions);

  final int branch; // index of the StatefulShellBranch in router.dart
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Visible when the role has ANY of these (empty = always visible).
  final List<Permission> permissions;
}

const _destinations = [
  _Dest(0, 'Home', Icons.dashboard_outlined, Icons.dashboard, []),
  _Dest(1, 'People', Icons.people_outline, Icons.people, [Permission.viewMembers]),
  _Dest(2, 'Planning', Icons.calendar_month_outlined, Icons.calendar_month,
      [Permission.viewPlanning, Permission.markAttendance]),
  _Dest(3, 'Finance', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet,
      [Permission.viewFinance, Permission.requestPurchase]),
  _Dest(4, 'Work', Icons.badge_outlined, Icons.badge, [Permission.logWork]),
];

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final church = ref.watch(churchProvider).value;
    if (church != null && !church.isActive) return const _SuspendedScreen();

    final role = ref.watch(currentRoleProvider);
    final membership = ref.watch(activeMembershipProvider);
    final width = MediaQuery.of(context).size.width;
    final wide = width >= 900;

    final visible = [
      for (final d in _destinations)
        if (d.permissions.isEmpty || d.permissions.any((p) => ref.watch(canProvider(p)))) d,
    ];
    final selected = visible.indexWhere((d) => d.branch == shell.currentIndex);
    if (selected < 0) {
      // The current tab is not available for this role: go to the first one.
      WidgetsBinding.instance.addPostFrameCallback((_) => shell.goBranch(visible.first.branch));
    }

    void go(int i) => shell.goBranch(visible[i].branch, initialLocation: visible[i].branch == shell.currentIndex);

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (ref.watch(canProvider(Permission.useChat)))
            IconButton(
              tooltip: 'Messages',
              icon: const Icon(Icons.forum_outlined),
              onPressed: () => context.push('/messages'),
            ),
          const SizedBox(width: 4),
        ],
        titleSpacing: 0,
        title: Row(
          children: [
            const ChurchLogo(size: 34),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(membership?.churchName ?? 'Church',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17)),
                  Text(role.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
      drawer: const _AppDrawer(),
      body: wide
          ? Row(
        children: [
          NavigationRail(
            selectedIndex: selected < 0 ? 0 : selected,
            extended: width >= 1250,
            labelType: width >= 1250 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            onDestinationSelected: go,
            destinations: [
              for (final d in visible)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: ContentWidth(child: shell)),
        ],
      )
          : shell,
      bottomNavigationBar: wide || visible.length < 2
          ? null
          : NavigationBar(
        selectedIndex: selected < 0 ? 0 : selected,
        onDestinationSelected: go,
        destinations: [
          for (final d in visible)
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
        ],
      ),
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final user = ref.watch(authStateProvider).value;
    final membership = ref.watch(activeMembershipProvider);
    final name = user?.displayName ?? '';

    void open(String path) {
      Navigator.pop(context);
      context.push(path);
    }

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.forestDeep,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InitialAvatar(name, size: 54, onDark: true),
                        const SizedBox(height: 14),
                        Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(user?.email ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
                        const SizedBox(height: 10),
                        Text('${role.label} at ${membership?.churchName ?? ''}',
                            style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const PatternBand(height: 14),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ListTile(leading: const Icon(Icons.event_outlined), title: const Text('Events'), onTap: () => open('/events')),
                if (ref.watch(canProvider(Permission.viewInventory)))
                  ListTile(leading: const Icon(Icons.inventory_2_outlined), title: const Text('Inventory'), onTap: () => open('/inventory')),
                if (ref.watch(canProvider(Permission.useChat)))
                  ListTile(leading: const Icon(Icons.forum_outlined), title: const Text('Messages'), onTap: () => open('/messages')),
                if (Permissions.can(role, Permission.manageUsers)) ...[
                  ListTile(
                    leading: const Icon(Icons.manage_accounts_outlined),
                    title: const Text('Team and logins'),
                    onTap: () => open('/team'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: const Text('Church settings'),
                    onTap: () => open('/settings'),
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('Change password'),
                  onTap: () => open('/change-password'),
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.swap_horiz),
                  title: const Text('Switch church'),
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(activeChurchIdProvider.notifier).set(null);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(activeChurchIdProvider.notifier).set(null);
                    ref.read(authRepositoryProvider).signOut();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuspendedScreen extends ConsumerWidget {
  const _SuspendedScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pause_circle_outline, size: 64),
              const SizedBox(height: 16),
              Text('This church account is suspended',
                  style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Please contact the system administrator.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => ref.read(activeChurchIdProvider.notifier).set(null),
                child: const Text('Switch church'),
              ),
              TextButton(
                onPressed: () {
                  ref.read(activeChurchIdProvider.notifier).set(null);
                  ref.read(authRepositoryProvider).signOut();
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}