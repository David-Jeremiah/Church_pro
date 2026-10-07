import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/prompt_dialog.dart';
import '../../../core/widgets/status_chip.dart';
import '../../budget/domain/budget_models.dart';
import '../../finance/domain/finance_models.dart';
import '../domain/requisition.dart';

class RequisitionDetailScreen extends ConsumerWidget {
  const RequisitionDetailScreen({super.key, required this.requisitionId});

  final String requisitionId;

  void _toast(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(requisitionsProvider).value?.where((x) => x.id == requisitionId).firstOrNull;
    if (r == null) {
      return Scaffold(appBar: AppBar(title: const Text('Request')), body: const Center(child: CircularProgressIndicator()));
    }

    final role = ref.watch(currentRoleProvider);
    final uid = ref.watch(authStateProvider).value?.uid;
    final currency = ref.watch(currencyProvider);
    final churchId = ref.watch(activeChurchIdProvider)!;
    final repo = ref.read(procurementRepositoryProvider);
    final canApprove = Permissions.can(role, Permission.approvePurchase);
    final canProcess = Permissions.can(role, Permission.processPurchase) || canApprove;
    final isMine = r.requestedBy == uid;
    String money(int v) => formatMoney(v, currency: currency);

    Future<void> approve() async {
      final block = ref.read(churchProvider).value?.blockOverBudget ?? true;
      final lines = ref.read(budgetLinesProvider(r.budgetId)).value ?? const <BudgetLine>[];
      final line = lines.where((l) => l.id == r.budgetLineId).firstOrNull;
      if (line != null && r.amount > line.remaining && block) {
        _toast(context, 'Not enough budget: only ${money(line.remaining)} left in "${line.name}".');
        return;
      }
      await repo.approve(churchId, r, approverName: ref.read(authStateProvider).value?.displayName ?? '');
    }

    Future<void> reject() async {
      final reason = await promptText(context, title: 'Reject request', label: 'Reason');
      if (reason != null && reason.isNotEmpty) await repo.reject(churchId, r, reason);
    }

    Future<void> pay() async {
      final result = await showDialog<_PayChoice>(context: context, builder: (_) => const _PayDialog());
      if (result != null) {
        await repo.markPaid(churchId, r, fund: result.fund, category: result.category, method: result.method);
      }
    }

    final actions = <Widget>[
      if (r.status == RequisitionStatus.submitted && canApprove) ...[
        FilledButton.icon(onPressed: approve, icon: const Icon(Icons.check), label: const Text('Approve')),
        OutlinedButton.icon(onPressed: reject, icon: const Icon(Icons.close), label: const Text('Reject')),
      ],
      if (r.status == RequisitionStatus.submitted && (canApprove || isMine))
        TextButton(onPressed: () => repo.cancel(churchId, r), child: const Text('Cancel request')),
      if (r.status == RequisitionStatus.approved && canProcess) ...[
        FilledButton.icon(
            onPressed: () => repo.markOrdered(churchId, r), icon: const Icon(Icons.shopping_cart_checkout), label: const Text('Mark as ordered')),
        TextButton(onPressed: () => repo.cancel(churchId, r), child: const Text('Cancel and release budget')),
      ],
      if (r.status == RequisitionStatus.ordered && canProcess)
        FilledButton.icon(
            onPressed: () => repo.markReceived(churchId, r), icon: const Icon(Icons.inventory_2_outlined), label: const Text('Mark as received')),
      if (r.status == RequisitionStatus.received && canProcess)
        FilledButton.icon(onPressed: pay, icon: const Icon(Icons.payments_outlined), label: const Text('Record payment')),
    ];

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 120, child: Text(label, style: Theme.of(context).textTheme.labelMedium)),
              Expanded(child: Text(value)),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase request')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(child: Text(r.title, style: Theme.of(context).textTheme.titleLarge)),
            StatusChip(r.status.label, color: r.status.color),
          ]),
          const SizedBox(height: 12),
          row('Amount', money(r.amount)),
          row('Budget line', r.budgetLineName),
          if (r.vendor.isNotEmpty) row('Supplier', r.vendor),
          row('Requested by', r.requestedByName),
          row('Date', formatDate(r.createdAt)),
          if (r.description.isNotEmpty) row('Details', r.description),
          if (r.rejectionReason != null) row('Rejected because', r.rejectionReason!),
          if (r.status == RequisitionStatus.paid) row('Ledger', 'Expense posted to the ledger'),
          const SizedBox(height: 16),
          for (final a in actions) Padding(padding: const EdgeInsets.only(bottom: 8), child: a),
          if (actions.isEmpty && r.status != RequisitionStatus.paid && r.status != RequisitionStatus.rejected && r.status != RequisitionStatus.cancelled)
            const Text('Waiting for the next step by the finance team.'),
          if (r.status == RequisitionStatus.paid)
            TextButton(onPressed: () => context.pop(), child: const Text('Back')),
        ],
      ),
    );
  }
}

class _PayChoice {
  const _PayChoice(this.fund, this.category, this.method);

  final Fund fund;
  final FinanceCategory category;
  final PaymentMethod method;
}

class _PayDialog extends ConsumerStatefulWidget {
  const _PayDialog();

  @override
  ConsumerState<_PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends ConsumerState<_PayDialog> {
  String? _fundId;
  String? _categoryId;
  PaymentMethod _method = PaymentMethod.cash;

  @override
  Widget build(BuildContext context) {
    final funds = (ref.watch(fundsProvider).value ?? const <Fund>[]).where((f) => f.active).toList();
    final cats = (ref.watch(categoriesProvider).value ?? const <FinanceCategory>[])
        .where((c) => c.type == TxType.expense)
        .toList();
    final fund = funds.where((f) => f.id == _fundId).firstOrNull;
    final cat = cats.where((c) => c.id == _categoryId).firstOrNull;

    return AlertDialog(
      title: const Text('Record payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: fund?.id,
            decoration: const InputDecoration(labelText: 'Pay from fund'),
            items: [for (final f in funds) DropdownMenuItem(value: f.id, child: Text(f.name))],
            onChanged: (v) => setState(() => _fundId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: cat?.id,
            decoration: const InputDecoration(labelText: 'Expense category'),
            items: [for (final c in cats) DropdownMenuItem(value: c.id, child: Text(c.name))],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PaymentMethod>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Payment method'),
            items: [for (final m in PaymentMethod.values) DropdownMenuItem(value: m, child: Text(m.label))],
            onChanged: (v) => setState(() => _method = v ?? _method),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: fund == null || cat == null ? null : () => Navigator.pop(context, _PayChoice(fund, cat, _method)),
          child: const Text('Pay'),
        ),
      ],
    );
  }
}
