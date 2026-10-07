import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../budget/domain/budget_models.dart';
import '../../finance/domain/finance_models.dart';

/// Raise a purchase request. The budget is checked now, not when the invoice arrives.
class RequisitionFormScreen extends ConsumerStatefulWidget {
  const RequisitionFormScreen({super.key});

  @override
  ConsumerState<RequisitionFormScreen> createState() => _RequisitionFormScreenState();
}

class _RequisitionFormScreenState extends ConsumerState<RequisitionFormScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _vendor = TextEditingController();
  final _amount = TextEditingController();
  String? _lineId;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_title, _description, _vendor, _amount]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(BudgetLine line) async {
    final user = ref.read(authStateProvider).value!;
    setState(() => _busy = true);
    try {
      await ref.read(procurementRepositoryProvider).submit(
            ref.read(activeChurchIdProvider)!,
            title: _title.text.trim(),
            description: _description.text.trim(),
            vendor: _vendor.text.trim(),
            amount: int.parse(_amount.text.trim()),
            budgetId: line.budgetId,
            budgetLineId: line.id,
            budgetLineName: line.name,
            requesterName: user.displayName,
          );
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final block = ref.watch(churchProvider).value?.blockOverBudget ?? true;
    final budget = ref.watch(activeBudgetProvider);
    final lines = budget == null
        ? const <BudgetLine>[]
        : (ref.watch(budgetLinesProvider(budget.id)).value ?? const <BudgetLine>[])
            .where((l) => l.type == TxType.expense)
            .toList();
    final line = lines.where((l) => l.id == _lineId).firstOrNull;
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    final over = line != null && amount > line.remaining;
    final ready = _title.text.trim().isNotEmpty && amount > 0 && line != null && !(over && block);

    return Scaffold(
      appBar: AppBar(title: const Text('New purchase request')),
      body: budget == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'There is no active budget yet.\nAsk the accountant or administrator to activate one before requesting purchases.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _title,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'What do you need? (e.g. 10 plastic chairs)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Details / reason (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(controller: _vendor, decoration: const InputDecoration(labelText: 'Preferred supplier (optional)')),
                const SizedBox(height: 12),
                TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: 'Estimated cost ($currency)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('line-${lines.length}'),
                  initialValue: lines.any((l) => l.id == _lineId) ? _lineId : null,
                  decoration: InputDecoration(labelText: 'Budget line (${budget.name})'),
                  items: [for (final l in lines) DropdownMenuItem(value: l.id, child: Text(l.name))],
                  onChanged: (v) => setState(() => _lineId = v),
                ),
                if (line != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    over
                        ? 'Over budget: only ${formatMoney(line.remaining, currency: currency)} left in "${line.name}".'
                            '${block ? ' This request cannot be submitted.' : ' It will be flagged for the approver.'}'
                        : 'Available in "${line.name}": ${formatMoney(line.remaining, currency: currency)}',
                    style: TextStyle(color: over ? Theme.of(context).colorScheme.error : null),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: ready && !_busy ? () => _submit(line) : null,
                  child: _busy
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Submit for approval'),
                ),
              ],
            ),
    );
  }
}
