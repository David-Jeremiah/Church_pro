import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/attendance/domain/church_service.dart';
import '../features/attendance/presentation/attendance_screen.dart';
import '../features/attendance/presentation/service_attendance_screen.dart';
import '../features/auth/presentation/change_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/budget/presentation/budget_detail_screen.dart';
import '../features/church/presentation/church_picker_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/events/presentation/events_screen.dart';
import '../features/finance/presentation/finance_screen.dart';
import '../features/finance/presentation/member_statement_screen.dart';
import '../features/members/domain/member.dart';
import '../features/members/presentation/member_form_screen.dart';
import '../features/members/presentation/members_screen.dart';
import '../features/platform/presentation/add_church_screen.dart';
import '../features/platform/presentation/platform_admins_screen.dart';
import '../features/platform/presentation/platform_home_screen.dart';
import '../features/procurement/presentation/requisition_detail_screen.dart';
import '../features/procurement/presentation/requisition_form_screen.dart';
import '../features/team/presentation/team_screen.dart';
import '../features/work/presentation/work_screen.dart';
import 'app_shell.dart';
import 'providers.dart';
import 'splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Created per router (not a global) so two routers can never share one key.
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authStateProvider, (_, _) => refresh.value++);
  ref.listen(isPlatformAdminProvider, (_, _) => refresh.value++);
  ref.listen(mustChangePasswordProvider, (_, _) => refresh.value++);
  ref.listen(activeChurchIdProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      String? only(String target) => loc == target ? null : target;

      final auth = ref.read(authStateProvider);
      if (auth.isLoading) return only('/splash');
      if (auth.value == null) return only('/login');

      final platform = ref.read(isPlatformAdminProvider);
      final mustChange = ref.read(mustChangePasswordProvider);
      if (platform.isLoading || mustChange.isLoading) return only('/splash');

      if (mustChange.value == true) return only('/change-password');
      if (loc == '/change-password') return null;

      if (platform.value == true) return loc.startsWith('/platform') ? null : '/platform';
      if (loc.startsWith('/platform')) return '/';

      final hasChurch = ref.read(activeChurchIdProvider) != null;
      if (!hasChurch) return only('/churches');
      if (loc == '/login' || loc == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/change-password', builder: (_, _) => const ChangePasswordScreen()),
      GoRoute(path: '/churches', builder: (_, _) => const ChurchPickerScreen()),

      // Platform admin (system owner)
      GoRoute(
        path: '/platform',
        builder: (_, _) => const PlatformHomeScreen(),
        routes: [
          GoRoute(path: 'add', builder: (_, _) => const AddChurchScreen()),
          GoRoute(path: 'admins', builder: (_, _) => const PlatformAdminsScreen()),
        ],
      ),

      // Pages opened from the drawer
      GoRoute(path: '/events', builder: (_, _) => const EventsScreen()),
      GoRoute(path: '/team', builder: (_, _) => const TeamScreen()),

      // Church app with bottom navigation. Branch order matters: see AppShell.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/members',
              builder: (_, _) => const MembersScreen(),
              routes: [
                GoRoute(
                  path: 'form',
                  parentNavigatorKey: rootKey,
                  builder: (_, state) => MemberFormScreen(member: state.extra as Member?),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/attendance',
              builder: (_, _) => const AttendanceScreen(),
              routes: [
                GoRoute(
                  path: 'service',
                  parentNavigatorKey: rootKey,
                  builder: (_, state) => ServiceAttendanceScreen(service: state.extra as ChurchService),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/finance',
              builder: (_, _) => const FinanceScreen(),
              routes: [
                GoRoute(
                  path: 'member/:id',
                  parentNavigatorKey: rootKey,
                  builder: (_, state) => MemberStatementScreen(
                    memberId: state.pathParameters['id']!,
                    initialYear: int.tryParse(state.uri.queryParameters['year'] ?? '') ?? DateTime.now().year,
                  ),
                ),
                GoRoute(
                  path: 'budget/:id',
                  parentNavigatorKey: rootKey,
                  builder: (_, state) => BudgetDetailScreen(budgetId: state.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'request/new',
                  parentNavigatorKey: rootKey,
                  builder: (_, _) => const RequisitionFormScreen(),
                ),
                GoRoute(
                  path: 'request/:id',
                  parentNavigatorKey: rootKey,
                  builder: (_, state) => RequisitionDetailScreen(requisitionId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/work', builder: (_, _) => const WorkScreen()),
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});