import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/reporting_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/finance_models.dart';
import 'receipts.dart';

/// Everything one person has given in a year, with receipts and a printable statement.
class MemberStatementScreen extends ConsumerStatefulWidget {
  const MemberStatementScreen({super.key, required this.memberId, required this.initialYear});

  final String memberId;
  final int initialYear;

  @override
  ConsumerState<MemberStatementScreen> createState() => _MemberStatementScreenState();
}

class _MemberStatementScreenState extends ConsumerState<MemberStatementScreen> {
  late int _year = widget.initialYear;

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    String money(int v) => formatMoney(v, currency: currency);
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);

    final all = ref.watch(memberTransactionsProvider(widget.memberId)).value ?? const <FinanceTransaction>[];
    final income = all.where((t) => t.type == TxType.income && !t.voided).toList();
    final member = (ref.watch(membersProvider).value ?? const []).where((m) => m.id == widget.memberId).firstOrNull;
    final name = member?.fullName ?? (income.isEmpty ? 'Member' : (income.first.memberName ?? 'Member'));

    final years = {...income.map((t) => t.date.year), DateTime.now().year, widget.initialYear}.toList()
      ..sort((a, b) => b.compareTo(a));
    final entries = income.where((t) => t.date.year == _year).toList();

    final total = entries.fold<int>(0, (s, t) => s + t.amount);
    int of(String id) => entries.where((t) => t.categoryId == id).fold<int>(0, (s, t) => s + t.amount);
    final tithe = of('tithe');
    final offering = of('offering');

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            tooltip: 'Print or save the yearly statement',
            icon: const Icon(Icons.print_outlined),
            onPressed: entries.isEmpty
                ? null
                : () => openStatement(context, ref, memberName: name, year: _year, entries: entries),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ContentWidth(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final y in years)
                  ChoiceChip(label: Text('$y'), selected: y == _year, onSelected: (_) => setState(() => _year = y)),
              ],
            ),
            const SizedBox(height: 14),
            FigureStrip(figures: [
              Figure('Total in $_year', money(total), color: AppColors.success),
              Figure('Tithes', money(tithe)),
              Figure('Offerings', money(offering)),
              Figure('Other', money(total - tithe - offering)),
            ]),
            SectionTitle(entries.isEmpty ? 'No gifts in $_year' : '${entries.length} gifts in $_year'),
            if (entries.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < entries.length; i++) ...[
                      if (i > 0) const Divider(),
                      ListTile(
                        title: Text(entries[i].categoryName),
                        subtitle: Text(
                          '${formatDate(entries[i].date)}.  ${entries[i].method.label}.  '
                              '${entries[i].receiptNo != null ? 'Receipt ${entries[i].receiptNo}' : 'No receipt yet'}',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(money(entries[i].amount), style: moneyStyle(context)?.copyWith(fontSize: 15)),
                            IconButton(
                              tooltip: entries[i].receiptNo == null ? 'Issue receipt' : 'View receipt',
                              icon: const Icon(Icons.receipt_long_outlined),
                              onPressed: () => openReceipt(context, ref, entries[i]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}