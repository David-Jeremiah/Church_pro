import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/inventory_providers.dart';
import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/inventory_models.dart';
import 'inventory_item_screen.dart';

/// Everything the church owns: equipment, supplies and stock.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _query = '';
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final canManage = Permissions.can(ref.watch(currentRoleProvider), Permission.manageInventory);
    final items = (ref.watch(inventoryItemsProvider).value ?? const <InventoryItem>[]).where((i) => i.active).toList();
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);

    final low = items.where((i) => i.isLow || i.isOut).length;
    final lent = items.where((i) => i.isLentOut).length;
    final shown = items.where((i) {
      final q = _query;
      final matches = q.isEmpty ||
          i.name.toLowerCase().contains(q) ||
          i.location.toLowerCase().contains(q) ||
          i.category.toLowerCase().contains(q);
      final passes = switch (_filter) {
        'low' => i.isLow || i.isOut,
        'lent' => i.isLentOut,
        _ => true,
      };
      return matches && passes;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
        onPressed: () => showInventoryItemSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add an item'),
      )
          : null,
      body: ContentWidth(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            FigureStrip(figures: [
              Figure('Items', '${items.length}'),
              Figure('Low or out', '$low', color: low > 0 ? AppColors.warning : null),
              Figure('Lent out', '$lent'),
            ]),
            const SizedBox(height: 14),
            TextField(
              decoration: const InputDecoration(hintText: 'Search by name, place or category', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(label: const Text('All'), selected: _filter == 'all', onSelected: (_) => setState(() => _filter = 'all')),
                ChoiceChip(label: const Text('Low stock'), selected: _filter == 'low', onSelected: (_) => setState(() => _filter = 'low')),
                ChoiceChip(label: const Text('Lent out'), selected: _filter == 'lent', onSelected: (_) => setState(() => _filter = 'lent')),
              ],
            ),
            const SizedBox(height: 12),
            if (shown.isEmpty)
              EmptyState(
                icon: Icons.inventory_2_outlined,
                title: items.isEmpty ? 'Nothing in the inventory yet' : 'No items match',
                message: items.isEmpty
                    ? (canManage ? 'Tap "Add an item" to list the first one.' : 'Items will appear here once they are added.')
                    : 'Try a different search.',
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
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0) const Divider(),
                      ListTile(
                        title: Text(shown[i].name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          [
                            shown[i].category,
                            if (shown[i].location.isNotEmpty) shown[i].location,
                            if (shown[i].isLentOut) 'With ${shown[i].custodian}',
                          ].join(',  '),
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (shown[i].isOut)
                              const StatusChip('Out', color: AppColors.danger)
                            else if (shown[i].isLow)
                              const StatusChip('Low', color: AppColors.warning),
                            const SizedBox(width: 10),
                            Text(
                              '${shown[i].quantity} ${shown[i].unit}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Icon(Icons.chevron_right, color: muted),
                          ],
                        ),
                        onTap: () => context.push('/inventory/${shown[i].id}'),
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