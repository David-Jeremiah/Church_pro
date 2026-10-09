import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/reporting_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/finance_models.dart';

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Income against expenses for a year, month by month, and by category.
class ReportsTab extends ConsumerStatefulWidget {
  const ReportsTab({super.key});

  @override
  ConsumerState<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<ReportsTab> {
  late int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    String money(int v) => formatMoney(v, currency: currency);
    final scheme = Theme.of(context).colorScheme;
    final thisYear = DateTime.now().year;

    final months = ref.watch(monthlyTotalsProvider(_year)).value ?? const <MonthTotal>[];
    final names = {
      for (final c in ref.watch(categoriesProvider).value ?? const <FinanceCategory>[]) c.id: c.name,
    };

    final income = List<int>.filled(12, 0);
    final expense = List<int>.filled(12, 0);
    final incomeByCat = <String, int>{};
    final expenseByCat = <String, int>{};
    for (final m in months) {
      if (m.month < 1 || m.month > 12) continue;
      income[m.month - 1] = m.income;
      expense[m.month - 1] = m.expense;
      m.incomeByCategory.forEach((k, v) => incomeByCat[k] = (incomeByCat[k] ?? 0) + v);
      m.expenseByCategory.forEach((k, v) => expenseByCat[k] = (expenseByCat[k] ?? 0) + v);
    }
    final totalIncome = income.fold<int>(0, (s, v) => s + v);
    final totalExpense = expense.fold<int>(0, (s, v) => s + v);
    final net = totalIncome - totalExpense;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
      children: [
        Row(
          children: [
            Text('Report for', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _year,
              underline: const SizedBox.shrink(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.primary),
              items: [for (var y = thisYear; y > thisYear - 6; y--) DropdownMenuItem(value: y, child: Text('$y'))],
              onChanged: (v) => setState(() => _year = v ?? _year),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FigureStrip(figures: [
          Figure('Income', money(totalIncome), color: AppColors.success),
          Figure('Expenses', money(totalExpense), color: AppColors.danger),
          Figure(net >= 0 ? 'Surplus' : 'Deficit', money(net.abs()),
              color: net >= 0 ? AppColors.success : AppColors.danger),
        ]),
        const SectionTitle('Income against expenses'),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _Legend(AppColors.success, 'Income'),
                const SizedBox(width: 16),
                _Legend(AppColors.danger, 'Expenses'),
              ]),
              const SizedBox(height: 14),
              _MonthBars(income: income, expense: expense, money: money),
            ],
          ),
        ),
        const SectionTitle('Where the money came from'),
        _CategoryBars(values: incomeByCat, names: names, color: AppColors.success, money: money),
        const SectionTitle('Where it went'),
        _CategoryBars(values: expenseByCat, names: names, color: AppColors.danger, money: money),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 6),
    Text(label, style: Theme.of(context).textTheme.labelMedium),
  ]);
}

class _MonthBars extends StatelessWidget {
  const _MonthBars({required this.income, required this.expense, required this.money});

  final List<int> income;
  final List<int> expense;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final peak = math.max(1, math.max(income.fold<int>(0, math.max), expense.fold<int>(0, math.max)));
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var m = 0; m < 12; m++)
                Expanded(
                  child: LayoutBuilder(builder: (context, box) {
                    double h(int v) => v <= 0 ? 0 : math.max(3, box.maxHeight * v / peak);
                    return Tooltip(
                      message: '${_monthNames[m]}\nIncome ${money(income[m])}\nExpenses ${money(expense[m])}',
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 7,
                            height: h(income[m]),
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Container(
                            width: 7,
                            height: h(expense[m]),
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          for (final n in _monthNames)
            Expanded(child: Text(n, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: muted))),
        ]),
      ],
    );
  }
}

class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.values, required this.names, required this.color, required this.money});

  final Map<String, int> values;
  final Map<String, String> names;
  final Color color;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);
    final entries = values.entries.where((e) => e.value != 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (s, e) => s + e.value);

    if (entries.isEmpty) return Text('Nothing recorded for this year.', style: TextStyle(color: muted));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(names[e.key] ?? e.key, style: Theme.of(context).textTheme.titleSmall)),
                    Text(money(e.value), style: moneyStyle(context)?.copyWith(fontSize: 14)),
                    SizedBox(
                      width: 44,
                      child: Text(
                        total == 0 ? '' : '${(100 * e.value / total).round()}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: total == 0 ? 0 : (e.value / total).clamp(0, 1).toDouble(), color: color),
                ],
              ),
            ),
        ],
      ),
    );
  }
}