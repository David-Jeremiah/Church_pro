import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/prompt_dialog.dart';
import '../../finance/domain/finance_models.dart';
import '../domain/budget_models.dart';

class BudgetDetailScreen extends ConsumerWidget {
  const BudgetDetailScreen({super.key, required this.budgetId});

  final String budgetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = Permissions.can(ref.watch(currentRoleProvider), Permission.manageBudgets);
    final currency = ref.watch(currencyProvider);
    final budget = ref.watch(budgetsProvider).value?.where((b) => b.id == budgetId).firstOrNull;
    final lines = ref.watch(budgetLinesProvider(budgetId));
    final churchId = ref.watch(activeChurchIdProvider)!;
    String money(int v) => formatMoney(v, currency: currency);

    return Scaffold(
      appBar: AppBar(
        title: Text(budget?.name ?? 'Budget'),
        actions: [
          if (canManage && budget != null && !budget.isActive)
            TextButton(
              onPressed: () => ref
                  .read(budgetRepositoryProvider)
                  .activate(churchId, budgetId, previousActiveId: ref.read(activeBudgetProvider)?.id),
              child: const Text('Make active'),
            ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _AddLineSheet(budgetId: budgetId),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add line'),
            )
          : null,
      body: lines.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('No lines yet. Add income and expense lines.'));
          Widget section(String title, TxType type) {
            final items = list.where((l) => l.type == type).toList();
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final l in items) _LineTile(line: l, canManage: canManage, money: money),
              ],
            );
          }

          return ListView(children: [
            section('Expenses', TxType.expense),
            section('Income', TxType.income),
            const SizedBox(height: 80),
          ]);
        },
      ),
    );
  }
}

class _LineTile extends ConsumerWidget {
  const _LineTile({required this.line, required this.canManage, required this.money});

  final BudgetLine line;
  final bool canManage;
  final String Function(int) money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final over = line.remaining < 0;
    final isExpense = line.type == TxType.expense;
    return ListTile(
      title: Text(line.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LinearProgressIndicator(value: line.usedFraction, color: over ? Colors.red : null),
          const SizedBox(height: 4),
          Text(
            isExpense
                ? 'Planned ${money(line.planned)} · Spent ${money(line.actual)} · Reserved ${money(line.committed)} · Left ${money(line.remaining)}'
                : 'Target ${money(line.planned)} · Received ${money(line.actual)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: over ? Colors.red : null),
          ),
        ],
      ),
      onTap: canManage
          ? () async {
              final v = await promptText(context, title: 'Change planned amount', label: line.name);
              final amount = int.tryParse(v ?? '');
              if (amount != null && amount >= 0) {
                await ref
                    .read(budgetRepositoryProvider)
                    .updatePlanned(ref.read(activeChurchIdProvider)!, line.budgetId, line.id, amount);
              }
            }
          : null,
    );
  }
}

class _AddLineSheet extends ConsumerStatefulWidget {
  const _AddLineSheet({required this.budgetId});

  final String budgetId;

  @override
  ConsumerState<_AddLineSheet> createState() => _AddLineSheetState();
}

class _AddLineSheetState extends ConsumerState<_AddLineSheet> {
  final _name = TextEditingController();
  final _planned = TextEditingController();
  TxType _type = TxType.expense;

  @override
  void dispose() {
    _name.dispose();
    _planned.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final planned = int.tryParse(_planned.text.trim());
    if (_name.text.trim().isEmpty || planned == null || planned < 0) return;
    await ref.read(budgetRepositoryProvider).addLine(
          ref.read(activeChurchIdProvider)!,
          widget.budgetId,
          name: _name.text.trim(),
          type: _type,
          planned: planned,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<TxType>(
            segments: const [
              ButtonSegment(value: TxType.expense, label: Text('Expense')),
              ButtonSegment(value: TxType.income, label: Text('Income')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
          TextField(controller: _name, autofocus: true, decoration: const InputDecoration(labelText: 'Line name (e.g. Electricity)')),
          const SizedBox(height: 12),
          TextField(
            controller: _planned,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Planned amount for the year'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Add line')),
        ],
      ),
    );
  }
}
