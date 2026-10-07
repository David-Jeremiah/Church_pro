import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/roles.dart';
import 'providers.dart';

String _initial(String? name) => (name == null || name.isEmpty) ? '?' : name[0].toUpperCase();

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
  _Dest(2, 'Services', Icons.fact_check_outlined, Icons.fact_check, [Permission.markAttendance]),
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
    final user = ref.watch(authStateProvider).value;
    final membership = ref.watch(activeMembershipProvider);
    final visible = [
      for (final d in _destinations)
        if (d.permissions.isEmpty || d.permissions.any((p) => Permissions.can(role, p))) d,
    ];
    final selected = visible.indexWhere((d) => d.branch == shell.currentIndex);
    if (selected < 0) {
      // The current tab is not available for this role: go to the first one.
      WidgetsBinding.instance.addPostFrameCallback((_) => shell.goBranch(visible.first.branch));
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(membership?.churchName ?? 'Church', style: const TextStyle(fontSize: 18)),
            Text(role.label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(user?.displayName ?? ''),
                accountEmail: Text(user?.email ?? ''),
                currentAccountPicture: CircleAvatar(child: Text(_initial(user?.displayName))),
              ),
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Events'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/events');
                },
              ),
              if (Permissions.can(role, Permission.manageUsers))
                ListTile(
                  leading: const Icon(Icons.manage_accounts),
                  title: const Text('Team & logins'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/team');
                  },
                ),
              ListTile(
                leading: const Icon(Icons.lock_reset),
                title: const Text('Change password'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/change-password');
                },
              ),
              const Divider(),
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
      ),
      body: shell,
      bottomNavigationBar: visible.length < 2
          ? null
          : NavigationBar(
              selectedIndex: selected < 0 ? 0 : selected,
              onDestinationSelected: (i) =>
                  shell.goBranch(visible[i].branch, initialLocation: visible[i].branch == shell.currentIndex),
              destinations: [
                for (final d in visible)
                  NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
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
