import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/utils/formatters.dart';
import '../../finance/domain/finance_models.dart';
import '../../procurement/domain/requisition.dart';
import '../../work/domain/work_log.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool can(Permission p) => ref.watch(canProvider(p));
    final user = ref.watch(authStateProvider).value;
    final currency = ref.watch(currencyProvider);
    String money(int v) => formatMoney(v, currency: currency);

    final cards = <Widget>[];

    // ── Work today (anyone who logs work)
    if (can(Permission.logWork)) {
      final today = ref.watch(todayWorkLogProvider);
      final text = today == null
          ? 'Not clocked in yet'
          : today.isOpen
              ? 'Working from ${today.mode.label.toLowerCase()} since ${formatTime(today.clockIn)}'
              : 'Done: ${formatDuration(today.worked!)} from ${today.mode.label.toLowerCase()}';
      cards.add(Card(
        child: ListTile(
          leading: Icon(today?.mode.icon ?? Icons.badge_outlined),
          title: const Text('My work today'),
          subtitle: Text(text),
          trailing: today == null ? FilledButton(onPressed: () => context.go('/work'), child: const Text('Clock in')) : null,
          onTap: () => context.go('/work'),
        ),
      ));
    }

    // ── Approvals waiting (admin)
    if (can(Permission.approvePurchase)) {
      final pending = (ref.watch(requisitionsProvider).value ?? const <Requisition>[])
          .where((r) => r.status == RequisitionStatus.submitted)
          .length;
      cards.add(Card(
        child: ListTile(
          leading: Icon(Icons.approval, color: pending > 0 ? Colors.orange : null),
          title: const Text('Purchase requests awaiting approval'),
          trailing: Text('$pending', style: Theme.of(context).textTheme.titleLarge),
          onTap: () => context.go('/finance'),
        ),
      ));
    }

    // ── Money this month (admin / accountant)
    if (can(Permission.viewFinance)) {
      final month = ref.watch(monthTransactionsProvider).value ?? const <FinanceTransaction>[];
      int sum(TxType t) => month.where((x) => !x.voided && x.type == t).fold<int>(0, (s, x) => s + x.amount);
      final income = sum(TxType.income);
      final expense = sum(TxType.expense);
      cards.add(Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This month', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Income   ${money(income)}'),
              Text('Expenses ${money(expense)}'),
              Text('Net      ${money(income - expense)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: income >= expense ? Colors.green.shade700 : Colors.red.shade700)),
            ],
          ),
        ),
      ));
    }

    // ── Team today (admin)
    if (can(Permission.viewTeamWork)) {
      final team = (ref.watch(teamProvider).value ?? const [])
          .where((m) => m.active && Permissions.can(m.role, Permission.logWork))
          .toList();
      final key = dayKey(DateTime.now());
      final logs = (ref.watch(teamWorkLogsProvider).value ?? const <WorkLog>[]).where((l) => l.date == key).toList();
      int n(WorkMode m) => logs.where((l) => l.mode == m).length;
      final notIn = team.where((m) => !logs.any((l) => l.uid == m.uid)).length;
      cards.add(Card(
        child: ListTile(
          leading: const Icon(Icons.groups),
          title: const Text('Team today'),
          subtitle: Text('Office ${n(WorkMode.office)} · Home ${n(WorkMode.home)} · Field ${n(WorkMode.field)} · Not in $notIn'),
          onTap: () => context.go('/work'),
        ),
      ));
    }

    // ── People & services
    if (can(Permission.viewMembers)) {
      final members = ref.watch(membersProvider).value ?? const [];
      cards.add(Card(
        child: ListTile(
          leading: const Icon(Icons.people),
          title: const Text('Members'),
          trailing: Text('${members.length}', style: Theme.of(context).textTheme.titleLarge),
          onTap: () => context.go('/members'),
        ),
      ));
    }
    if (can(Permission.markAttendance)) {
      final services = ref.watch(servicesProvider).value ?? const [];
      final last = services.isEmpty ? null : services.first;
      final present = last == null ? 0 : (ref.watch(presentIdsProvider(last.id)).value?.length ?? 0);
      cards.add(Card(
        child: ListTile(
          leading: const Icon(Icons.fact_check),
          title: Text(last?.title ?? 'Last service'),
          trailing: Text(last == null ? '—' : '$present present', style: Theme.of(context).textTheme.titleMedium),
          onTap: () => context.go('/attendance'),
        ),
      ));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Welcome, ${user?.displayName ?? ''}', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        ...cards,
        if (cards.isEmpty) const Text('Use the menu for events and your account.'),
      ],
    );
  }
}
