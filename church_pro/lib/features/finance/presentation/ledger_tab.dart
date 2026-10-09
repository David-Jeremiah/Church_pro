import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../domain/finance_models.dart';
import 'receipts.dart';
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
        content: const Text('It stays visible, struck through, and is taken out of totals, fund balances, giving records and budgets.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Void entry'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(financeRepositoryProvider).voidTransaction(ref.read(activeChurchIdProvider)!, t);
    }
  }

  void _actions(FinanceTransaction t, bool canRecord, String currency) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(t.description.isEmpty ? t.categoryName : t.description),
              subtitle: Text('${formatMoney(t.amount, currency: currency)} on ${formatDate(t.date)}'),
            ),
            const Divider(),
            if (t.type == TxType.income && !t.voided)
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(t.receiptNo == null ? 'Issue an official receipt' : 'View receipt ${t.receiptNo}'),
                onTap: () {
                  Navigator.pop(ctx);
                  openReceipt(context, ref, t);
                },
              ),
            if (canRecord && !t.voided && t.source == 'manual')
              ListTile(
                leading: const Icon(Icons.block, color: AppColors.danger),
                title: const Text('Void this entry'),
                onTap: () {
                  Navigator.pop(ctx);
                  _void(t);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canRecord = Permissions.can(ref.watch(currentRoleProvider), Permission.recordTransactions);
    final currency = ref.watch(currencyProvider);
    final txs = ref.watch(recentTransactionsProvider);
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);

    return Scaffold(
      backgroundColor: Colors.transparent,
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
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(label: const Text('All'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
                ChoiceChip(label: const Text('Money in'), selected: _filter == TxType.income, onSelected: (_) => setState(() => _filter = TxType.income)),
                ChoiceChip(label: const Text('Money out'), selected: _filter == TxType.expense, onSelected: (_) => setState(() => _filter = TxType.expense)),
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
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (_, i) {
                    final t = list[i];
                    final income = t.type == TxType.income;
                    final color = t.voided ? Colors.grey : (income ? AppColors.success : AppColors.danger);
                    return ListTile(
                      leading: Icon(income ? Icons.south_west : Icons.north_east, color: color),
                      title: Text(
                        t.description.isEmpty ? t.categoryName : t.description,
                        style: t.voided ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                      ),
                      subtitle: Text(
                        [
                          t.categoryName,
                          t.fundName,
                          formatDate(t.date),
                          if (t.memberName != null) t.memberName!,
                          if (t.serviceTitle != null) t.serviceTitle!,
                          if (t.receiptNo != null) 'Receipt ${t.receiptNo}',
                        ].join(',  '),
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      trailing: Text(
                        '${income ? '+' : '-'}${formatMoney(t.amount, currency: currency)}',
                        style: TextStyle(color: color, fontWeight: FontWeight.w700),
                      ),
                      onTap: () => _actions(t, canRecord, currency),
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