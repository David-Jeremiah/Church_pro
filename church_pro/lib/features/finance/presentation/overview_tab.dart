import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/finance_models.dart';
import 'transaction_form.dart';

class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final month = ref.watch(monthTransactionsProvider).value ?? const <FinanceTransaction>[];
    final funds = ref.watch(fundsProvider).value ?? const <Fund>[];
    final budget = ref.watch(activeBudgetProvider);
    final lines = budget == null ? null : ref.watch(budgetLinesProvider(budget.id)).value;
    final scheme = Theme.of(context).colorScheme;
    String money(int v) => formatMoney(v, currency: currency);

    int sum(TxType t) => month.where((x) => !x.voided && x.type == t).fold<int>(0, (s, x) => s + x.amount);
    final income = sum(TxType.income);
    final expense = sum(TxType.expense);

    final expenseLines = (lines ?? const []).where((l) => l.type == TxType.expense).toList();
    final planned = expenseLines.fold<int>(0, (s, l) => s + l.planned);
    final used = expenseLines.fold<int>(0, (s, l) => s + l.committed + l.actual);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 40),
      children: [
        const SectionTitle('Record money'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => showTransactionSheet(context, categoryId: 'tithe', heading: 'Record tithe'),
              icon: const Icon(Icons.volunteer_activism),
              label: const Text('Record tithe'),
            ),
            FilledButton.icon(
              onPressed: () => showTransactionSheet(context, categoryId: 'offering', heading: 'Record offertory'),
              icon: const Icon(Icons.church),
              label: const Text('Record offertory'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => showTransactionSheet(context, heading: 'Record other income'),
              icon: const Icon(Icons.add_card),
              label: const Text('Other income'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => showTransactionSheet(context, type: TxType.expense, heading: 'Record an expense'),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Record an expense'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/finance/budget/new'),
              icon: const Icon(Icons.savings_outlined),
              label: const Text('Create a budget'),
            ),
          ],
        ),
        const SectionTitle('This month'),
        FigureStrip(figures: [
          Figure('Came in', money(income), color: AppColors.success),
          Figure('Went out', money(expense), color: AppColors.danger),
          Figure('Left over', money(income - expense), color: income >= expense ? AppColors.success : AppColors.danger),
        ]),
        const SizedBox(height: 12),
        if (budget != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: InkWell(
              onTap: () => context.push('/finance/budget/${budget.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text('Active budget: ${budget.name}', style: Theme.of(context).textTheme.titleSmall)),
                    const Icon(Icons.chevron_right),
                  ]),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: planned <= 0 ? 0 : (used / planned).clamp(0, 1).toDouble()),
                  const SizedBox(height: 6),
                  Text('Spent or reserved ${money(used)} of ${money(planned)} planned expenses'),
                ],
              ),
            ),
          )
        else
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            leading: const Icon(Icons.info_outline),
            title: const Text('No active budget'),
            subtitle: const Text('Create one so purchases can be checked against it.'),
            onTap: () => context.push('/finance/budget/new'),
          ),
        const SectionTitle('Funds'),
        for (final f in funds)
          ListTile(
            title: Text(f.name),
            subtitle: f.restricted ? const Align(alignment: Alignment.centerLeft, child: StatusChip('Restricted')) : null,
            trailing: Text(money(f.balance), style: moneyStyle(context)?.copyWith(fontSize: 15)),
          ),
        if (funds.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Setting up funds...')),
      ],
    );
  }
}