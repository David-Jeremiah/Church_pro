import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../members/domain/member.dart';
import '../domain/finance_models.dart';

/// Bottom sheet to record income (tithes, offerings, donations) or an expense.
class TransactionForm extends ConsumerStatefulWidget {
  const TransactionForm({super.key});

  @override
  ConsumerState<TransactionForm> createState() => _TransactionFormState();
}

class _LineOption {
  const _LineOption(this.id, this.budgetId, this.name);

  final String id;
  final String budgetId;
  final String name;
}

class _TransactionFormState extends ConsumerState<TransactionForm> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  TxType _type = TxType.income;
  PaymentMethod _method = PaymentMethod.cash;
  DateTime _date = DateTime.now();
  String? _fundId, _categoryId, _memberId, _serviceId, _lineId;
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
    required List<_LineOption> lines,
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
    final service = ref.read(servicesProvider).value?.where((s) => s.id == _serviceId).firstOrNull;

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
          memberId: _type == TxType.income ? member?.id : null,
          memberName: _type == TxType.income ? member?.fullName : null,
          serviceId: _type == TxType.income ? service?.id : null,
          serviceTitle: _type == TxType.income ? service?.title : null,
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
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final services = (ref.watch(servicesProvider).value ?? const []).take(20).toList();
    final budget = ref.watch(activeBudgetProvider);
    final lines = budget == null
        ? <_LineOption>[]
        : (ref.watch(budgetLinesProvider(budget.id)).value ?? const [])
        .where((l) => l.type == _type)
        .map((l) => _LineOption(l.id, l.budgetId, l.name))
        .toList();

    final fundId = funds.any((f) => f.id == _fundId) ? _fundId : funds.firstOrNull?.id;
    final selectedFund = funds.where((f) => f.id == fundId).firstOrNull;
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    final needsGiver = _type == TxType.income && (_categoryId == 'tithe' || _categoryId == 'offering') && _memberId == null;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<TxType>(
              segments: const [
                ButtonSegment(value: TxType.income, label: Text('Money in'), icon: Icon(Icons.south_west)),
                ButtonSegment(value: TxType.expense, label: Text('Money out'), icon: Icon(Icons.north_east)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _categoryId = null;
                _lineId = null;
                _memberId = null;
                _serviceId = null;
              }),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: 'Amount ($currency)'),
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
            if (_type == TxType.income) ...[
              const SizedBox(height: 12),
              Autocomplete<Member>(
                key: ValueKey('giver-${_type.name}'),
                displayStringForOption: (m) => m.fullName,
                optionsBuilder: (v) {
                  final q = v.text.trim().toLowerCase();
                  if (q.isEmpty) return const Iterable<Member>.empty();
                  return members.where((m) => m.fullName.toLowerCase().contains(q) || m.phone.contains(q)).take(8);
                },
                onSelected: (m) => setState(() => _memberId = m.id),
                fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (_) {
                    if (_memberId != null) setState(() => _memberId = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'Given by (type a name)',
                    helperText: needsGiver
                        ? 'Choose the person so their yearly giving and receipt are recorded'
                        : 'Leave empty for anonymous giving',
                    prefixIcon: Icon(_memberId == null ? Icons.person_search_outlined : Icons.check_circle,
                        color: _memberId == null ? null : Theme.of(context).colorScheme.primary),
                    suffixIcon: controller.text.isEmpty
                        ? null
                        : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        controller.clear();
                        setState(() => _memberId = null);
                      },
                    ),
                  ),
                ),
              ),
              if (services.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _serviceId,
                  decoration: const InputDecoration(labelText: 'Collected at service (optional)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Not linked to a service')),
                    for (final s in services)
                      DropdownMenuItem<String?>(value: s.id, child: Text('${s.title}, ${formatDate(s.date)}')),
                  ],
                  onChanged: (v) => setState(() => _serviceId = v),
                ),
              ],
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: [for (final m in PaymentMethod.values) DropdownMenuItem(value: m, child: Text(m.label))],
              onChanged: (v) => setState(() => _method = v ?? _method),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined),
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
              decoration: const InputDecoration(labelText: 'Notes or reference (optional)'),
            ),
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
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : () => _save(funds: funds, categories: categories, lines: lines),
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : const Text('Save entry'),
            ),
          ],
        ),
      ),
    );
  }
}