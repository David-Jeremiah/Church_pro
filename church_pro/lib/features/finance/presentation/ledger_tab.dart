import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/utils/formatters.dart';
import '../domain/finance_models.dart';
import 'transaction_form.dart';

class LedgerTab extends ConsumerStatefulWidget {
  const LedgerTab({super.key});

  @override
  ConsumerState<LedgerTab> createState() => _LedgerTabState();
}

class _LedgerTabState extends ConsumerState<LedgerTab> {
  TxType? _filter;

  Future<void> _void(FinanceTransaction t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void this entry?'),
        content: const Text('It stays visible, struck through, and is removed from totals, fund balances and budgets.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Void')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(financeRepositoryProvider).voidTransaction(ref.read(activeChurchIdProvider)!, t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRecord = Permissions.can(ref.watch(currentRoleProvider), Permission.recordTransactions);
    final currency = ref.watch(currencyProvider);
    final txs = ref.watch(recentTransactionsProvider);

    return Scaffold(
      floatingActionButton: canRecord
          ? FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const TransactionForm(),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add entry'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(label: const Text('All'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
                ChoiceChip(label: const Text('Income'), selected: _filter == TxType.income, onSelected: (_) => setState(() => _filter = TxType.income)),
                ChoiceChip(label: const Text('Expenses'), selected: _filter == TxType.expense, onSelected: (_) => setState(() => _filter = TxType.expense)),
              ],
            ),
          ),
          Expanded(
            child: txs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (all) {
                final list = all.where((t) => _filter == null || t.type == _filter).toList();
                if (list.isEmpty) return const Center(child: Text('No entries yet'));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final t = list[i];
                    final income = t.type == TxType.income;
                    final color = t.voided ? Colors.grey : (income ? Colors.green.shade700 : Colors.red.shade700);
                    return ListTile(
                      leading: Icon(income ? Icons.arrow_downward : Icons.arrow_upward, color: color),
                      title: Text(
                        t.description.isEmpty ? t.categoryName : t.description,
                        style: t.voided ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                      ),
                      subtitle: Text([
                        t.categoryName,
                        t.fundName,
                        formatDate(t.date),
                        if (t.memberName != null) t.memberName!,
                        if (t.source == 'procurement') 'purchase',
                      ].join(' · ')),
                      trailing: Text(
                        '${income ? '+' : '-'}${formatMoney(t.amount, currency: currency)}',
                        style: TextStyle(color: color, fontWeight: FontWeight.w600),
                      ),
                      onLongPress: canRecord && !t.voided && t.source == 'manual' ? () => _void(t) : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
