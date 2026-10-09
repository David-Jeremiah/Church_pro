import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/reporting_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/finance_models.dart';

/// Tithes and offerings: how much each person has given this year, and what
/// was collected at each service.
class GivingTab extends ConsumerStatefulWidget {
  const GivingTab({super.key});

  @override
  ConsumerState<GivingTab> createState() => _GivingTabState();
}

class _ServiceTotal {
  _ServiceTotal(this.title, this.date);

  final String title;
  final DateTime date;
  int total = 0;
}

class _GivingTabState extends ConsumerState<GivingTab> {
  late int _year = DateTime.now().year;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    String money(int v) => formatMoney(v, currency: currency);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);
    final thisYear = DateTime.now().year;

    final totals = ref.watch(givingTotalsProvider(_year)).value ?? const <GivingTotal>[];
    final list = totals.where((g) => g.memberName.toLowerCase().contains(_query)).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final all = totals.fold<int>(0, (s, g) => s + g.total);
    final tithes = totals.fold<int>(0, (s, g) => s + g.of('tithe'));
    final offerings = totals.fold<int>(0, (s, g) => s + g.of('offering'));

    // Offertory by service (from the latest ledger entries).
    final recent = ref.watch(recentTransactionsProvider).value ?? const <FinanceTransaction>[];
    final byService = <String, _ServiceTotal>{};
    for (final t in recent) {
      if (t.voided || t.type != TxType.income || t.serviceId == null) continue;
      byService.putIfAbsent(t.serviceId!, () => _ServiceTotal(t.serviceTitle ?? 'Service', t.date)).total += t.amount;
    }
    final services = byService.values.toList()..sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
      children: [
        Row(
          children: [
            Text('Giving in', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _year,
              underline: const SizedBox.shrink(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.primary),
              items: [for (var y = thisYear; y > thisYear - 6; y--) DropdownMenuItem(value: y, child: Text('$y'))],
              onChanged: (v) => setState(() => _year = v ?? _year),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FigureStrip(figures: [
          Figure('Tithes', money(tithes), color: AppColors.success),
          Figure('Offerings', money(offerings), color: AppColors.success),
          Figure('All named giving', money(all)),
        ]),
        const SectionTitle('Giving by person'),
        TextField(
          decoration: const InputDecoration(hintText: 'Search a name', prefixIcon: Icon(Icons.search)),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 10),
        if (list.isEmpty)
          const EmptyState(
            icon: Icons.volunteer_activism_outlined,
            title: 'No giving recorded for this year',
            message: 'When you record a tithe or offering, choose who gave it. Their yearly total appears here.',
          )
        else
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) const Divider(),
                  InkWell(
                    onTap: () => context.push('/finance/member/${list[i].memberId}?year=$_year'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          InitialAvatar(list[i].memberName, size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(list[i].memberName, style: Theme.of(context).textTheme.titleSmall),
                                Text(
                                  [
                                    if (list[i].of('tithe') > 0) 'Tithe ${money(list[i].of('tithe'))}',
                                    if (list[i].of('offering') > 0) 'Offering ${money(list[i].of('offering'))}',
                                  ].join(',  '),
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text(money(list[i].total), style: moneyStyle(context)?.copyWith(fontSize: 15)),
                          Icon(Icons.chevron_right, color: muted),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SectionTitle('Recent offertory by service'),
        if (services.isEmpty)
          Text(
            'Choose a service when you record income and the total collected at each service shows here.',
            style: TextStyle(color: muted),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              children: [
                for (var i = 0; i < services.length && i < 8; i++) ...[
                  if (i > 0) const Divider(),
                  ListTile(
                    leading: const Icon(Icons.church_outlined),
                    title: Text(services[i].title),
                    subtitle: Text(formatDate(services[i].date)),
                    trailing: Text(money(services[i].total), style: moneyStyle(context)?.copyWith(fontSize: 15)),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}