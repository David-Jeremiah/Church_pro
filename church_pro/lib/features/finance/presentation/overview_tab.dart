import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/finance_models.dart';

class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final month = ref.watch(monthTransactionsProvider).value ?? const <FinanceTransaction>[];
    final funds = ref.watch(fundsProvider).value ?? const <Fund>[];
    final budget = ref.watch(activeBudgetProvider);
    final lines = budget == null ? null : ref.watch(budgetLinesProvider(budget.id)).value;

    int sum(TxType t) =>
        month.where((x) => !x.voided && x.type == t).fold<int>(0, (s, x) => s + x.amount);
    final income = sum(TxType.income);
    final expense = sum(TxType.expense);
    final totalCash = funds.fold<int>(0, (s, f) => s + f.balance);

    String money(int v) => formatMoney(v, currency: currency);

    Widget stat(String label, int value, Color color) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(money(value),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        );

    final expenseLines = (lines ?? const []).where((l) => l.type == TxType.expense).toList();
    final planned = expenseLines.fold<int>(0, (s, l) => s + l.planned);
    final used = expenseLines.fold<int>(0, (s, l) => s + l.committed + l.actual);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('This month', style: Theme.of(context).textTheme.titleMedium),
        Row(children: [
          stat('Income', income, Colors.green.shade700),
          stat('Expenses', expense, Colors.red.shade700),
        ]),
        Row(children: [
          stat('Net', income - expense, income - expense >= 0 ? Colors.green.shade700 : Colors.red.shade700),
          stat('Total in all funds', totalCash, Theme.of(context).colorScheme.primary),
        ]),
        const SizedBox(height: 12),
        if (budget != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Budget: ${budget.name}', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: planned <= 0 ? 0 : (used / planned).clamp(0, 1).toDouble()),
                  const SizedBox(height: 6),
                  Text('Spent or reserved ${money(used)} of ${money(planned)} planned expenses'),
                ],
              ),
            ),
          )
        else
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('No active budget'),
              subtitle: Text('Create one in the Budgets tab so purchases can be checked against it.'),
            ),
          ),
        const SizedBox(height: 12),
        Text('Funds', style: Theme.of(context).textTheme.titleMedium),
        for (final f in funds)
          ListTile(
            title: Text(f.name),
            subtitle: f.restricted ? const Align(alignment: Alignment.centerLeft, child: StatusChip('Restricted')) : null,
            trailing: Text(money(f.balance), style: Theme.of(context).textTheme.titleSmall),
          ),
        if (funds.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Setting up funds...')),
      ],
    );
  }
}
