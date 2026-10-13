import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/access.dart';
import '../core/constants/roles.dart';
import '../core/utils/formatters.dart';
import '../data/firebase/firebase_attendance_repository.dart';
import '../data/firebase/firebase_auth_repository.dart';
import '../data/firebase/firebase_church_repository.dart';
import '../data/firebase/firebase_event_repository.dart';
import '../data/firebase/firebase_member_repository.dart';
import '../data/firebase/firebase_provisioning.dart';
import '../features/attendance/data/attendance_repository.dart';
import '../features/attendance/domain/church_service.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/app_user.dart';
import '../features/budget/data/budget_repository.dart';
import '../features/budget/domain/budget_models.dart';
import '../features/church/data/church_repository.dart';
import '../features/church/domain/church.dart';
import '../features/church/domain/membership.dart';
import '../features/events/data/event_repository.dart';
import '../features/events/domain/church_event.dart';
import '../features/finance/data/finance_repository.dart';
import '../features/finance/domain/finance_models.dart';
import '../features/members/data/member_repository.dart';
import '../features/members/domain/member.dart';
import '../features/platform/data/platform_repository.dart';
import '../features/settings/data/church_settings_repository.dart';
import '../features/procurement/data/procurement_repository.dart';
import '../features/procurement/domain/requisition.dart';
import '../features/team/data/team_repository.dart';
import '../features/team/domain/team_member.dart';
import '../features/work/data/work_repository.dart';
import '../features/work/domain/work_log.dart';

// ── Repositories ─────────────────────────────────────────────────────────
final _provisioningProvider = Provider<Provisioning>((ref) => Provisioning());
final authRepositoryProvider = Provider<AuthRepository>((ref) => FirebaseAuthRepository());
final churchRepositoryProvider = Provider<ChurchRepository>((ref) => FirebaseChurchRepository());
final platformRepositoryProvider =
Provider<PlatformRepository>((ref) => PlatformRepository(provisioning: ref.watch(_provisioningProvider)));
final teamRepositoryProvider =
Provider<TeamRepository>((ref) => TeamRepository(provisioning: ref.watch(_provisioningProvider)));
final memberRepositoryProvider = Provider<MemberRepository>((ref) => FirebaseMemberRepository());
final attendanceRepositoryProvider =
Provider<AttendanceRepository>((ref) => FirebaseAttendanceRepository());
final eventRepositoryProvider = Provider<EventRepository>((ref) => FirebaseEventRepository());
final financeRepositoryProvider = Provider<FinanceRepository>((ref) => FinanceRepository());
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) => BudgetRepository());
final procurementRepositoryProvider =
Provider<ProcurementRepository>((ref) => ProcurementRepository(ref.watch(financeRepositoryProvider)));
final workRepositoryProvider = Provider<WorkRepository>((ref) => WorkRepository());

// ── Session ──────────────────────────────────────────────────────────────
final authStateProvider = StreamProvider<AppUser?>(
      (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final isPlatformAdminProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(false);
  return ref.watch(authRepositoryProvider).watchIsPlatformAdmin(user.uid);
});

final mustChangePasswordProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(false);
  return ref.watch(authRepositoryProvider).watchMustChangePassword(user.uid);
});

// ── Active church (tenant) ───────────────────────────────────────────────
class ActiveChurchNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? churchId) => state = churchId;
}

final activeChurchIdProvider =
NotifierProvider<ActiveChurchNotifier, String?>(ActiveChurchNotifier.new);

final membershipsProvider = StreamProvider<List<Membership>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const <Membership>[]);
  return ref.watch(churchRepositoryProvider).watchMemberships(user.uid);
});

final activeMembershipProvider = Provider<Membership?>((ref) {
  final id = ref.watch(activeChurchIdProvider);
  final list = ref.watch(membershipsProvider).value ?? const <Membership>[];
  for (final m in list) {
    if (m.churchId == id) return m;
  }
  return null;
});

final currentRoleProvider = Provider<ChurchRole>(
      (ref) => ref.watch(activeMembershipProvider)?.role ?? ChurchRole.member,
);

/// The church admin's own choices about who sees what (People, Planning, Inventory,
/// Messages, Reports, Team work board). Empty until the admin changes something.
final accessProvider = StreamProvider<Map<String, List<String>>>((ref) {
  final churchId = ref.watch(activeChurchIdProvider);
  if (churchId == null) return Stream.value(const <String, List<String>>{});
  return ref.watch(settingsRepositoryProvider).watchAccess(churchId);
});

/// True when the signed-in user may use [permission] in the active church.
/// For the modules the admin can configure, the admin's choice wins over the default.
final canProvider = Provider.family<bool, Permission>((ref, permission) {
  final role = ref.watch(currentRoleProvider);
  final module = AccessModule.forPermission(permission);
  final chosen = module == null ? null : ref.watch(accessProvider).value?[module.name];
  if (chosen != null) return role == ChurchRole.admin || chosen.contains(role.name);
  return Permissions.can(role, permission);
});

Stream<T> _forChurch<T>(Ref ref, T empty, Stream<T> Function(String churchId) build) {
  final id = ref.watch(activeChurchIdProvider);
  if (id == null) return Stream.value(empty);
  return build(id);
}

final churchProvider = StreamProvider<Church?>(
      (ref) => _forChurch<Church?>(ref, null, ref.watch(churchRepositoryProvider).watchChurch),
);

final currencyProvider = Provider<String>((ref) => ref.watch(churchProvider).value?.currency ?? 'UGX');

// ── Church profile (logo, contact details) ───────────────────────────────
final settingsRepositoryProvider = Provider<ChurchSettingsRepository>((ref) => ChurchSettingsRepository());

final churchProfileProvider = StreamProvider<ChurchProfile>((ref) {
  final churchId = ref.watch(activeChurchIdProvider);
  if (churchId == null) return Stream.value(const ChurchProfile());
  return ref.watch(settingsRepositoryProvider).watchProfile(churchId);
});

// ── Platform admin ───────────────────────────────────────────────────────
final platformChurchesProvider =
StreamProvider<List<Church>>((ref) => ref.watch(platformRepositoryProvider).watchChurches());

// ── People, attendance, events ───────────────────────────────────────────
final membersProvider = StreamProvider<List<Member>>(
      (ref) => _forChurch(ref, const <Member>[], ref.watch(memberRepositoryProvider).watchMembers),
);

final servicesProvider = StreamProvider<List<ChurchService>>(
      (ref) => _forChurch(ref, const <ChurchService>[], ref.watch(attendanceRepositoryProvider).watchServices),
);

final presentIdsProvider = StreamProvider.family<Set<String>, String>((ref, serviceId) {
  final churchId = ref.watch(activeChurchIdProvider);
  if (churchId == null) return Stream.value(<String>{});
  return ref.watch(attendanceRepositoryProvider).watchPresent(churchId, serviceId);
});

final eventsProvider = StreamProvider<List<ChurchEvent>>(
      (ref) => _forChurch(ref, const <ChurchEvent>[], ref.watch(eventRepositoryProvider).watchEvents),
);

final teamProvider = StreamProvider<List<TeamMember>>(
      (ref) => _forChurch(ref, const <TeamMember>[], ref.watch(teamRepositoryProvider).watchTeam),
);

// ── Finance ──────────────────────────────────────────────────────────────
final fundsProvider = StreamProvider<List<Fund>>(
      (ref) => _forChurch(ref, const <Fund>[], ref.watch(financeRepositoryProvider).watchFunds),
);

final categoriesProvider = StreamProvider<List<FinanceCategory>>(
      (ref) => _forChurch(ref, const <FinanceCategory>[], ref.watch(financeRepositoryProvider).watchCategories),
);

/// Latest 100 ledger entries.
final recentTransactionsProvider = StreamProvider<List<FinanceTransaction>>(
      (ref) => _forChurch(
    ref,
    const <FinanceTransaction>[],
        (id) => ref.watch(financeRepositoryProvider).watchTransactions(id, limit: 100),
  ),
);

/// Every ledger entry since the start of this month (for totals).
final monthTransactionsProvider = StreamProvider<List<FinanceTransaction>>(
      (ref) => _forChurch(
    ref,
    const <FinanceTransaction>[],
        (id) => ref.watch(financeRepositoryProvider).watchTransactions(id, since: startOfMonth(DateTime.now())),
  ),
);

// ── Budgets ──────────────────────────────────────────────────────────────
final budgetsProvider = StreamProvider<List<Budget>>(
      (ref) => _forChurch(ref, const <Budget>[], ref.watch(budgetRepositoryProvider).watchBudgets),
);

final activeBudgetProvider = Provider<Budget?>((ref) {
  for (final b in ref.watch(budgetsProvider).value ?? const <Budget>[]) {
    if (b.isActive) return b;
  }
  return null;
});

final budgetLinesProvider = StreamProvider.family<List<BudgetLine>, String>((ref, budgetId) {
  final churchId = ref.watch(activeChurchIdProvider);
  if (churchId == null) return Stream.value(const <BudgetLine>[]);
  return ref.watch(budgetRepositoryProvider).watchLines(churchId, budgetId);
});

// ── Procurement ──────────────────────────────────────────────────────────
final requisitionsProvider = StreamProvider<List<Requisition>>((ref) {
  final churchId = ref.watch(activeChurchIdProvider);
  final user = ref.watch(authStateProvider).value;
  if (churchId == null || user == null) return Stream.value(const <Requisition>[]);
  final seesAll = ref.watch(canProvider(Permission.viewFinance));
  return ref
      .watch(procurementRepositoryProvider)
      .watchRequisitions(churchId, requesterUid: seesAll ? null : user.uid);
});

// ── Work log (office / home / field) ─────────────────────────────────────
final myWorkLogsProvider = StreamProvider<List<WorkLog>>((ref) {
  final churchId = ref.watch(activeChurchIdProvider);
  final user = ref.watch(authStateProvider).value;
  if (churchId == null || user == null) return Stream.value(const <WorkLog>[]);
  return ref.watch(workRepositoryProvider).watchMyLogs(churchId, user.uid);
});

final todayWorkLogProvider = Provider<WorkLog?>((ref) {
  final today = dayKey(DateTime.now());
  for (final l in ref.watch(myWorkLogsProvider).value ?? const <WorkLog>[]) {
    if (l.date == today) return l;
  }
  return null;
});

final teamWorkLogsProvider = StreamProvider<List<WorkLog>>(
      (ref) => _forChurch(ref, const <WorkLog>[], ref.watch(workRepositoryProvider).watchTeamLogs),
);