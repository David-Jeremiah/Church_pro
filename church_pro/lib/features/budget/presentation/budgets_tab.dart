import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/widgets/prompt_dialog.dart';
import '../../../core/widgets/status_chip.dart';

class BudgetsTab extends ConsumerWidget {
  const BudgetsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = Permissions.can(ref.watch(currentRoleProvider), Permission.manageBudgets);
    final budgets = ref.watch(budgetsProvider);

    return Scaffold(
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () async {
                final name = await promptText(context, title: 'New budget', label: 'Name (e.g. FY 2027)');
                if (name == null || name.isEmpty) return;
                final year = int.tryParse(RegExp(r'20\d\d').firstMatch(name)?.group(0) ?? '') ?? DateTime.now().year;
                await ref.read(budgetRepositoryProvider).createBudget(ref.read(activeChurchIdProvider)!, name: name, year: year);
              },
              icon: const Icon(Icons.add),
              label: const Text('New budget'),
            )
          : null,
      body: budgets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('No budgets yet'))
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final b = list[i];
                  return ListTile(
                    leading: const Icon(Icons.savings_outlined),
                    title: Text(b.name),
                    subtitle: Text('${b.year}'),
                    trailing: StatusChip(
                      b.status[0].toUpperCase() + b.status.substring(1),
                      color: b.isActive ? Colors.green : Colors.grey,
                    ),
                    onTap: () => context.push('/finance/budget/${b.id}'),
                  );
                },
              ),
      ),
    );
  }
}
