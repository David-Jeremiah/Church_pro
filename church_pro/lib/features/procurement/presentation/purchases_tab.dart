import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_chip.dart';

class PurchasesTab extends ConsumerWidget {
  const PurchasesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canRequest = Permissions.can(ref.watch(currentRoleProvider), Permission.requestPurchase);
    final seesAll = ref.watch(canProvider(Permission.viewFinance));
    final currency = ref.watch(currencyProvider);
    final requests = ref.watch(requisitionsProvider);

    return Scaffold(
      floatingActionButton: canRequest
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/finance/request/new'),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('New request'),
            )
          : null,
      body: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? Center(child: Text(seesAll ? 'No purchase requests yet' : 'You have not made any requests yet'))
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final r = list[i];
                  return ListTile(
                    title: Text(r.title),
                    subtitle: Text([
                      if (seesAll) r.requestedByName,
                      formatDate(r.createdAt),
                      r.budgetLineName,
                    ].join(' · ')),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatMoney(r.amount, currency: currency), style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 4),
                        StatusChip(r.status.label, color: r.status.color),
                      ],
                    ),
                    onTap: () => context.push('/finance/request/${r.id}'),
                  );
                },
              ),
      ),
    );
  }
}
