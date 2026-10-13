import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../members/domain/member.dart';
import '../domain/finance_models.dart';

String _label(String name) {
  final spaced = name.replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ');
  return spaced.isEmpty ? spaced : spaced[0].toUpperCase() + spaced.substring(1).toLowerCase();
}

/// Record one member's tithe. When opened for a specific member ([memberId]) it
/// closes after saving; otherwise it stays open so many tithes can be entered in a row.
class TitheEntryScreen extends ConsumerStatefulWidget {
  const TitheEntryScreen({super.key, this.memberId});

  final String? memberId;

  @override
  ConsumerState<TitheEntryScreen> createState() => _TitheEntryScreenState();
}

class _TitheEntryScreenState extends ConsumerState<TitheEntryScreen> {
  final _memberText = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  Member? _member;
  String? _fundId;
  PaymentMethod _method = PaymentMethod.cash;
  DateTime _date = DateTime.now();
  bool _presetApplied = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _memberText.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final churchId = ref.read(activeChurchIdProvider);
    if (churchId == null) return;

    final member = _member;
    final amount = int.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (member == null) {
      setState(() => _error = 'Choose the member who gave.');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter the amount.');
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
    final category = income.where((c) => c.id == 'tithe').firstOrNull ?? income.firstOrNull;
    if (category == null) {
      setState(() => _error = 'No income categories are set up yet.');
      return;
    }

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
          date: _date,
          description: _note.text.trim().isEmpty ? 'Tithe' : _note.text.trim(),
          memberId: member.id,
          memberName: member.fullName,
          source: 'tithe',
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tithe recorded for ${member.fullName}')));
      if (widget.memberId != null) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/finance');
        }
      } else {
        setState(() {
          _busy = false;
          _member = null;
          _memberText.clear();
          _amount.clear();
          _note.clear();
        });
      }
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
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final funds = (ref.watch(fundsProvider).value ?? const <Fund>[]).where((f) => f.active).toList();
    final currency = ref.watch(currencyProvider);
    final scheme = Theme.of(context).colorScheme;

    if (!_presetApplied && widget.memberId != null && members.isNotEmpty) {
      final preset = members.where((m) => m.id == widget.memberId).firstOrNull;
      if (preset != null) {
        _member = preset;
        _memberText.text = preset.fullName;
      }
      _presetApplied = true;
    }
    if (_fundId == null && funds.isNotEmpty) {
      _fundId = funds.any((f) => f.id == 'general') ? 'general' : funds.first.id;
    }

    final sorted = [...members]..sort((a, b) => a.fullName.compareTo(b.fullName));

    return Scaffold(
      appBar: AppBar(title: const Text('Record tithes')),
      body: ContentWidth(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            DropdownMenu<Member>(
              controller: _memberText,
              initialSelection: _member,
              enableFilter: true,
              requestFocusOnTap: true,
              expandedInsets: EdgeInsets.zero,
              label: const Text('Member'),
              dropdownMenuEntries: [for (final m in sorted) DropdownMenuEntry(value: m, label: m.fullName)],
              onSelected: (m) => setState(() => _member = m),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Amount', prefixText: '$currency '),
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(formatDate(_date)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : const Text('Record tithe'),
            ),
          ],
        ),
      ),
    );
  }
}