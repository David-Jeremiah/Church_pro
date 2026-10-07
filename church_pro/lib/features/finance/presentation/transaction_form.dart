import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/formatters.dart';
import '../domain/finance_models.dart';

/// Bottom sheet to record income (tithes, offerings, donations) or an expense.
class TransactionForm extends ConsumerStatefulWidget {
  const TransactionForm({super.key});

  @override
  ConsumerState<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<TransactionForm> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  TxType _type = TxType.income;
  PaymentMethod _method = PaymentMethod.cash;
  DateTime _date = DateTime.now();
  String? _fundId, _categoryId, _memberId, _lineId;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save({
    required List<Fund> funds,
    required List<FinanceCategory> categories,
    required List<BudgetLineOption> lines,
  }) async {
    final amount = int.tryParse(_amount.text.trim());
    final fund = funds.where((f) => f.id == (_fundId ?? funds.firstOrNull?.id)).firstOrNull;
    final category = categories.where((c) => c.id == _categoryId).firstOrNull;
    if (amount == null || amount <= 0 || fund == null || category == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter an amount, a fund and a category')));
      return;
    }
    final line = lines.where((l) => l.id == _lineId).firstOrNull;
    final member = ref.read(membersProvider).value?.where((m) => m.id == _memberId).firstOrNull;

    setState(() => _busy = true);
    try {
      await ref.read(financeRepositoryProvider).record(
            ref.read(activeChurchIdProvider)!,
            FinanceTransaction(
              id: '',
              type: _type,
              amount: amount,
              fundId: fund.id,
              fundName: fund.name,
              categoryId: category.id,
              categoryName: category.name,
              method: _method,
              date: _date,
              description: _description.text.trim(),
              memberId: member?.id,
              memberName: member?.fullName,
              budgetId: line?.budgetId,
              budgetLineId: line?.id,
            ),
          );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final funds = (ref.watch(fundsProvider).value ?? const <Fund>[]).where((f) => f.active).toList();
    final categories =
        (ref.watch(categoriesProvider).value ?? const <FinanceCategory>[]).where((c) => c.type == _type).toList();
    final members = ref.watch(membersProvider).value ?? const [];
    final budget = ref.watch(activeBudgetProvider);
    final lines = budget == null
        ? <BudgetLineOption>[]
        : (ref.watch(budgetLinesProvider(budget.id)).value ?? const [])
            .where((l) => l.type == _type)
            .map((l) => BudgetLineOption(l.id, l.budgetId, l.name))
            .toList();

    final fundId = funds.any((f) => f.id == _fundId) ? _fundId : funds.firstOrNull?.id;
    final selectedFund = funds.where((f) => f.id == fundId).firstOrNull;
    final amount = int.tryParse(_amount.text.trim()) ?? 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<TxType>(
              segments: const [
                ButtonSegment(value: TxType.income, label: Text('Income'), icon: Icon(Icons.arrow_downward)),
                ButtonSegment(value: TxType.expense, label: Text('Expense'), icon: Icon(Icons.arrow_upward)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _categoryId = null;
                _lineId = null;
                _memberId = null;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: 'Amount ($currency)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('fund-$fundId-${funds.length}'),
              initialValue: fundId,
              decoration: InputDecoration(
                labelText: 'Fund',
                helperText: selectedFund?.restricted == true ? 'Restricted fund: use only for its stated purpose' : null,
                errorText: _type == TxType.expense && selectedFund != null && amount > selectedFund.balance
                    ? 'Only ${formatMoney(selectedFund.balance, currency: currency)} in this fund'
                    : null,
              ),
              items: [for (final f in funds) DropdownMenuItem(value: f.id, child: Text(f.name))],
              onChanged: (v) => setState(() => _fundId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('cat-${_type.name}-${categories.length}'),
              initialValue: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: [for (final m in PaymentMethod.values) DropdownMenuItem(value: m, child: Text(m.label))],
              onChanged: (v) => setState(() => _method = v ?? _method),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(formatDate(_date)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description / reference (optional)'),
            ),
            if (_type == TxType.income && members.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: ValueKey('member-${_type.name}'),
                initialValue: _memberId,
                decoration: const InputDecoration(labelText: 'Given by (optional)'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Anonymous / not recorded')),
                  for (final m in members) DropdownMenuItem<String?>(value: m.id, child: Text(m.fullName)),
                ],
                onChanged: (v) => setState(() => _memberId = v),
              ),
            ],
            if (lines.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: ValueKey('line-${_type.name}-${lines.length}'),
                initialValue: lines.any((l) => l.id == _lineId) ? _lineId : null,
                decoration: InputDecoration(labelText: 'Budget line (${budget!.name}, optional)'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Not linked to a budget line')),
                  for (final l in lines) DropdownMenuItem<String?>(value: l.id, child: Text(l.name)),
                ],
                onChanged: (v) => setState(() => _lineId = v),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : () => _save(funds: funds, categories: categories, lines: lines),
              child: _busy
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save entry'),
            ),
          ],
        ),
      ),
    );
  }
}

class BudgetLineOption {
  const BudgetLineOption(this.id, this.budgetId, this.name);

  final String id;
  final String budgetId;
  final String name;
}
