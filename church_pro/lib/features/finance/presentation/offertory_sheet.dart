import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../attendance/domain/church_service.dart';
import '../domain/finance_models.dart';

/// Record the offertory collected at a service as one income entry.
Future<void> showOffertorySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _OffertorySheet(),
  );
}

String _label(String name) {
  final spaced = name.replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ');
  return spaced.isEmpty ? spaced : spaced[0].toUpperCase() + spaced.substring(1).toLowerCase();
}

class _OffertorySheet extends ConsumerStatefulWidget {
  const _OffertorySheet();

  @override
  ConsumerState<_OffertorySheet> createState() => _OffertorySheetState();
}

class _OffertorySheetState extends ConsumerState<_OffertorySheet> {
  final _amount = TextEditingController();
  String? _serviceId;
  String? _fundId;
  PaymentMethod _method = PaymentMethod.cash;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final churchId = ref.read(activeChurchIdProvider);
    if (churchId == null) return;

    final amount = int.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter the amount collected.');
      return;
    }
    final fund = (ref.read(fundsProvider).value ?? const <Fund>[]).where((f) => f.id == _fundId).firstOrNull;
    if (fund == null) {
      setState(() => _error = 'Choose a fund.');
      return;
    }
    final income = (ref.read(categoriesProvider).value ?? const <FinanceCategory>[])
        .where((c) => c.type == TxType.income)
        .toList();
    final category = income.where((c) => c.id == 'offering').firstOrNull ?? income.firstOrNull;
    if (category == null) {
      setState(() => _error = 'No income categories are set up yet.');
      return;
    }
    final service =
        (ref.read(servicesProvider).value ?? const <ChurchService>[]).where((s) => s.id == _serviceId).firstOrNull;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(financeRepositoryProvider).record(
        churchId,
        FinanceTransaction(
          id: '',
          type: TxType.income,
          amount: amount,
          fundId: fund.id,
          fundName: fund.name,
          categoryId: category.id,
          categoryName: category.name,
          method: _method,
          date: DateTime.now(),
          description: service == null ? 'Offertory' : 'Offertory: ${service.title}',
          serviceId: service?.id,
          serviceTitle: service?.title,
          source: 'offertory',
        ),
      );
      messenger.showSnackBar(const SnackBar(content: Text('Offertory recorded')));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final funds = (ref.watch(fundsProvider).value ?? const <Fund>[]).where((f) => f.active).toList();
    final services = (ref.watch(servicesProvider).value ?? const <ChurchService>[]).take(10).toList();
    final currency = ref.watch(currencyProvider);
    final scheme = Theme.of(context).colorScheme;

    if (_fundId == null && funds.isNotEmpty) {
      _fundId = funds.any((f) => f.id == 'general') ? 'general' : funds.first.id;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Record offertory', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(labelText: 'Amount collected', prefixText: '$currency '),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: ValueKey('service-$_serviceId'),
              initialValue: _serviceId,
              decoration: const InputDecoration(labelText: 'Service (optional)'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Not tied to a service')),
                for (final s in services) DropdownMenuItem<String?>(value: s.id, child: Text(s.title)),
              ],
              onChanged: (v) => setState(() => _serviceId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('fund-$_fundId-${funds.length}'),
              initialValue: _fundId,
              decoration: const InputDecoration(labelText: 'Fund'),
              items: [for (final f in funds) DropdownMenuItem(value: f.id, child: Text(f.name))],
              onChanged: (v) => setState(() => _fundId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'How it was paid'),
              items: [for (final m in PaymentMethod.values) DropdownMenuItem(value: m, child: Text(_label(m.name)))],
              onChanged: (v) => setState(() => _method = v ?? _method),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const Text('Record'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}