import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/ui_kit.dart';

class BudgetsTab extends ConsumerWidget {
  const BudgetsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = Permissions.can(ref.watch(currentRoleProvider), Permission.manageBudgets);
    final budgets = ref.watch(budgetsProvider);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
        onPressed: () => context.push('/finance/budget/new'),
        icon: const Icon(Icons.add),
        label: const Text('Create a budget'),
      )
          : null,
      body: budgets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: EmptyState(
                icon: Icons.savings_outlined,
                title: 'No budgets yet',
                message: canManage
                    ? 'Tap "Create a budget". You can send it to the lead pastor for approval and discuss it with comments.'
                    : 'Budgets shared with you will appear here.',
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            children: [
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
                      ListTile(
                        leading: const Icon(Icons.savings_outlined),
                        title: Text(list[i].name),
                        subtitle: Text(
                          canManage && list[i].sharedWith.isNotEmpty
                              ? '${list[i].year}.  Shared with ${list[i].sharedWith.length} '
                              '${list[i].sharedWith.length == 1 ? 'person' : 'people'}.'
                              : '${list[i].year}',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        trailing: StatusChip(list[i].statusLabel, color: list[i].statusColor),
                        onTap: () => context.push('/finance/budget/${list[i].id}'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}