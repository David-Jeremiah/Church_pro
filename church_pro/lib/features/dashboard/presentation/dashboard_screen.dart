import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/inventory_providers.dart';
import '../../../app/planning_providers.dart';
import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../budget/domain/budget_models.dart';
import '../../finance/domain/finance_models.dart';
import '../../finance/presentation/offertory_sheet.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../planning/domain/planning_models.dart';
import '../../procurement/domain/requisition.dart';
import '../../work/domain/work_log.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool can(Permission p) => ref.watch(canProvider(p));

    final user = ref.watch(authStateProvider).value;
    final church = ref.watch(churchProvider).value;
    final role = ref.watch(currentRoleProvider);
    final currency = ref.watch(currencyProvider);
    String money(int v) => formatMoney(v, currency: currency);

    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Good morning' : (now.hour < 17 ? 'Good afternoon' : 'Good evening');
    final firstName = (user?.displayName ?? '').split(' ').first;

    final children = <Widget>[
      HeroBanner(
        title: firstName.isEmpty ? greeting : '$greeting, $firstName',
        subtitle: church?.name,
        pills: [role.label, formatDate(now)],
      ),
    ];

    // ── What needs attention ─────────────────────────────────────────────
    final attention = <Widget>[];
    final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];

    if (can(Permission.approveBudget)) {
      final waiting = budgets.where((b) => b.isPending).toList();
      if (waiting.isNotEmpty) {
        attention.add(AttentionRow(
          icon: Icons.fact_check_outlined,
          color: AppColors.warning,
          title: waiting.length == 1
              ? '"${waiting.first.name}" is waiting for your approval'
              : '${waiting.length} budgets are waiting for your approval',
          subtitle: 'Read it, add comments, then approve or ask for changes.',
          onTap: () => waiting.length == 1 ? context.push('/finance/budget/${waiting.first.id}') : context.go('/finance'),
        ));
      }
    }

    if (can(Permission.manageBudgets)) {
      final changes = budgets.where((b) => b.needsChanges).toList();
      if (changes.isNotEmpty) {
        attention.add(AttentionRow(
          icon: Icons.edit_note,
          color: AppColors.danger,
          title: changes.length == 1
              ? 'The lead pastor asked for changes to "${changes.first.name}"'
              : '${changes.length} budgets need changes',
          subtitle: 'Open the budget to read the note and send it again.',
          onTap: () => context.push('/finance/budget/${changes.first.id}'),
        ));
      }
    }

    if (can(Permission.approvePurchase)) {
      final pending = (ref.watch(requisitionsProvider).value ?? const <Requisition>[])
          .where((r) => r.status == RequisitionStatus.submitted)
          .length;
      if (pending > 0) {
        attention.add(AttentionRow(
          icon: Icons.approval,
          color: AppColors.warning,
          title: pending == 1 ? '1 purchase request is waiting for you' : '$pending purchase requests are waiting for you',
          subtitle: 'Review each one, then approve or reject it.',
          onTap: () => context.go('/finance'),
        ));
      }
    }

    if (can(Permission.viewFinance) && ref.watch(budgetsProvider).hasValue && ref.watch(activeBudgetProvider) == null) {
      attention.add(AttentionRow(
        icon: Icons.savings_outlined,
        color: AppColors.warning,
        title: 'No budget is active',
        subtitle: 'Staff cannot request purchases until you activate one.',
        onTap: () => context.push('/finance/budget/new'),
      ));
    }

    if (can(Permission.viewPlanning)) {
      final sunday = sundayOnOrAfter(now);
      final planned = (ref.watch(plannedServicesProvider).value ?? const <PlannedService>[])
          .where((s) => sameDay(s.date, sunday))
          .toList();
      final when = sameDay(sunday, now) ? 'Today' : 'Next Sunday (${formatDate(sunday)})';
      final plannedPath = '/attendance/sunday?date=${dayKey(sunday)}';
      if (planned.isEmpty) {
        attention.add(AttentionRow(
          icon: Icons.event_busy_outlined,
          color: AppColors.warning,
          title: '$when is not planned yet',
          subtitle: 'Choose three services or a joint service, then say who preaches and leads.',
          onTap: () => context.push(plannedPath),
        ));
      } else {
        final noPreacher = planned.where((s) => !s.hasPreacher).length;
        final noLeader = planned.where((s) => !s.hasLeader).length;
        if (noPreacher > 0 || noLeader > 0) {
          attention.add(AttentionRow(
            icon: Icons.record_voice_over_outlined,
            color: AppColors.warning,
            title: '$when: ${[
              if (noPreacher > 0) '$noPreacher without a preacher',
              if (noLeader > 0) '$noLeader without a service leader',
            ].join(', ')}',
            subtitle: 'Open the plan to assign them.',
            onTap: () => context.push(plannedPath),
          ));
        } else {
          attention.add(AttentionRow(
            icon: Icons.event_available,
            color: AppColors.success,
            title: '$when is planned: ${planned.first.isJoint ? 'a joint service' : '${planned.length} services'}, everyone assigned',
            onTap: () => context.push(plannedPath),
          ));
        }
      }
    }

    if (can(Permission.viewInventory)) {
      final low = (ref.watch(inventoryItemsProvider).value ?? const <InventoryItem>[])
          .where((i) => i.isLow || i.isOut)
          .length;
      if (low > 0) {
        attention.add(AttentionRow(
          icon: Icons.inventory_2_outlined,
          color: AppColors.warning,
          title: low == 1 ? '1 inventory item is low or out of stock' : '$low inventory items are low or out of stock',
          subtitle: 'Open the inventory to see which ones.',
          onTap: () => context.push('/inventory'),
        ));
      }
    }

    final today = ref.watch(todayWorkLogProvider);
    if (can(Permission.logWork)) {
      if (today == null) {
        attention.add(AttentionRow(
          icon: Icons.badge_outlined,
          color: AppColors.forest,
          title: 'You have not clocked in today',
          subtitle: 'Say whether you are in the office, at home or in the field.',
          onTap: () => context.go('/work'),
        ));
      } else {
        attention.add(AttentionRow(
          icon: today.mode.icon,
          color: AppColors.success,
          title: today.isOpen
              ? 'Working from ${today.mode.label.toLowerCase()} since ${formatTime(today.clockIn)}'
              : 'Finished today: ${formatDuration(today.worked!)} from ${today.mode.label.toLowerCase()}',
          onTap: () => context.go('/work'),
        ));
      }
    }

    if (attention.isNotEmpty) {
      children.add(const SectionTitle('Today'));
      children.addAll(attention);
    }

    // ── Money this month ────────────────────────────────────────────────
    if (can(Permission.viewFinance)) {
      final month = ref.watch(monthTransactionsProvider).value ?? const <FinanceTransaction>[];
      int sum(TxType t) => month.where((x) => !x.voided && x.type == t).fold<int>(0, (s, x) => s + x.amount);
      final income = sum(TxType.income);
      final expense = sum(TxType.expense);
      children
        ..add(const SectionTitle('Money this month'))
        ..add(FigureStrip(figures: [
          Figure('Came in', money(income), color: AppColors.success),
          Figure('Went out', money(expense), color: AppColors.danger),
          Figure('Left over', money(income - expense),
              color: income >= expense ? AppColors.success : AppColors.danger),
        ]));
    }

    // ── People ──────────────────────────────────────────────────────────
    final people = <Figure>[];
    if (can(Permission.viewMembers)) {
      people.add(Figure('Members', '${(ref.watch(membersProvider).value ?? const []).length}'));
    }
    if (can(Permission.markAttendance)) {
      final services = ref.watch(servicesProvider).value ?? const [];
      final last = services.isEmpty ? null : services.first;
      final present = last == null ? 0 : (ref.watch(presentIdsProvider(last.id)).value?.length ?? 0);
      people.add(Figure(last?.title ?? 'Last service', last == null ? 'None yet' : '$present present'));
    }
    if (people.isNotEmpty) {
      children
        ..add(const SectionTitle('People'))
        ..add(FigureStrip(figures: people));
    }

    // ── Team today (admin) ──────────────────────────────────────────────
    if (can(Permission.viewTeamWork)) {
      final team = (ref.watch(teamProvider).value ?? const [])
          .where((m) => m.active && Permissions.can(m.role, Permission.logWork))
          .toList();
      final key = dayKey(now);
      final logs = (ref.watch(teamWorkLogsProvider).value ?? const <WorkLog>[]).where((l) => l.date == key).toList();
      int n(WorkMode m) => logs.where((l) => l.mode == m).length;
      final notIn = team.where((m) => !logs.any((l) => l.uid == m.uid)).length;
      children
        ..add(const SectionTitle('Team today'))
        ..add(FigureStrip(figures: [
          Figure('Office', '${n(WorkMode.office)}'),
          Figure('Home', '${n(WorkMode.home)}'),
          Figure('Not in', '$notIn'),
        ]));
    }

    // ── Quick actions ───────────────────────────────────────────────────
    final actions = <Widget>[
      if (can(Permission.recordTransactions))
        FilledButton.icon(
          onPressed: () => context.push('/finance/tithes'),
          icon: const Icon(Icons.volunteer_activism),
          label: const Text('Record tithes'),
        ),
      if (can(Permission.recordTransactions))
        FilledButton.icon(
          onPressed: () => showOffertorySheet(context),
          icon: const Icon(Icons.church),
          label: const Text('Record offertory'),
        ),
      if (can(Permission.manageServices))
        FilledButton.tonalIcon(
          onPressed: () => context.push('/attendance/sunday?date=${dayKey(sundayOnOrAfter(now))}'),
          icon: const Icon(Icons.event_available),
          label: const Text('Plan a Sunday'),
        ),
      if (can(Permission.manageBudgets))
        FilledButton.tonalIcon(
          onPressed: () => context.push('/finance/budget/new'),
          icon: const Icon(Icons.savings_outlined),
          label: const Text('Create a budget'),
        ),
      if (can(Permission.manageMembers))
        FilledButton.tonalIcon(
          onPressed: () => context.push('/members/form'),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add a member'),
        ),
      if (can(Permission.markAttendance))
        FilledButton.tonalIcon(
          onPressed: () => context.go('/attendance'),
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('Open the planner'),
        ),
      if (can(Permission.requestPurchase))
        FilledButton.tonalIcon(
          onPressed: () => context.push('/finance/request/new'),
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('Request a purchase'),
        ),
    ];
    if (actions.isNotEmpty) {
      children
        ..add(const SectionTitle('Quick actions'))
        ..add(Wrap(spacing: 10, runSpacing: 10, children: actions));
    }

    if (children.length == 1) {
      children.add(const EmptyState(
        icon: Icons.event_outlined,
        title: 'Welcome',
        message: 'Open the menu to see church events and manage your account.',
      ));
    }

    return ContentWidth(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: children),
    );
  }
}