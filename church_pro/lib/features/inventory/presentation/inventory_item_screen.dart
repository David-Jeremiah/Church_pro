import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/inventory_providers.dart';
import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/inventory_models.dart';

/// One item: how many are in stock, who has it, and every change to the stock.
class InventoryItemScreen extends ConsumerWidget {
  const InventoryItemScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = Permissions.can(ref.watch(currentRoleProvider), Permission.manageInventory);
    final item = ref.watch(inventoryItemsProvider).value?.where((i) => i.id == itemId).firstOrNull;
    final moves = ref.watch(stockMovesProvider(itemId)).value ?? const <StockMove>[];
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);

    if (item == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'Edit details',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showInventoryItemSheet(context, item: item),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ContentWidth(
        maxWidth: 800,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${item.quantity}', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('${item.unit} in stock', style: TextStyle(color: muted)),
                      ),
                      const Spacer(),
                      if (item.isOut)
                        const StatusChip('Out of stock', color: AppColors.danger)
                      else if (item.isLow)
                        const StatusChip('Running low', color: AppColors.warning),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    [
                      item.category,
                      if (item.location.isNotEmpty) 'Kept at ${item.location}',
                      if (item.minLevel > 0) 'Warn at ${item.minLevel} or fewer',
                    ].join('.  '),
                    style: TextStyle(color: muted),
                  ),
                  if (item.isLentOut) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.person_outline, size: 18, color: AppColors.warning),
                      const SizedBox(width: 6),
                      Text('With ${item.custodian}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning)),
                    ]),
                  ],
                  if (item.notes.isNotEmpty) ...[const SizedBox(height: 10), Text(item.notes)],
                ],
              ),
            ),
            if (canManage) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => showStockSheet(context, item, StockKind.added),
                    icon: const Icon(Icons.add_box_outlined),
                    label: const Text('Add stock'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => showStockSheet(context, item, StockKind.taken),
                    icon: const Icon(Icons.outbox_outlined),
                    label: const Text('Take out'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showStockSheet(context, item, StockKind.counted),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Count it'),
                  ),
                ],
              ),
            ],
            const SectionTitle('History'),
            if (moves.isEmpty)
              Text('No changes recorded yet.', style: TextStyle(color: muted))
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
                    for (var i = 0; i < moves.length; i++) ...[
                      if (i > 0) const Divider(),
                      ListTile(
                        leading: Icon(
                          moves[i].delta > 0 ? Icons.south_west : (moves[i].delta < 0 ? Icons.north_east : Icons.fact_check_outlined),
                          color: moves[i].delta > 0 ? AppColors.success : (moves[i].delta < 0 ? AppColors.danger : muted),
                        ),
                        title: Text('${moves[i].kind.label}: ${moves[i].reason}'),
                        subtitle: Text(
                          '${formatDate(moves[i].createdAt)}, ${formatTime(moves[i].createdAt)}.  ${moves[i].byName}.'
                              '${moves[i].note.isEmpty ? '' : '  ${moves[i].note}'}',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              moves[i].delta == 0 ? '0' : (moves[i].delta > 0 ? '+${moves[i].delta}' : '${moves[i].delta}'),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text('now ${moves[i].balanceAfter}', style: TextStyle(color: muted, fontSize: 11)),
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

// ── Add or change an item ────────────────────────────────────────────────
Future<void> showInventoryItemSheet(BuildContext context, {InventoryItem? item}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ItemSheet(item: item),
);

class _ItemSheet extends ConsumerStatefulWidget {
  const _ItemSheet({this.item});

  final InventoryItem? item;

  @override
  ConsumerState<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<_ItemSheet> {
  late final _name = TextEditingController(text: widget.item?.name);
  late final _unit = TextEditingController(text: widget.item?.unit ?? 'pieces');
  late final _quantity = TextEditingController(text: '1');
  late final _min = TextEditingController(text: '${widget.item?.minLevel ?? 0}');
  late final _location = TextEditingController(text: widget.item?.location);
  late final _notes = TextEditingController(text: widget.item?.notes);
  late String _category = inventoryCategories.contains(widget.item?.category) ? widget.item!.category : inventoryCategories.first;
  late bool _active = widget.item?.active ?? true;
  bool _busy = false;

  bool get _isNew => widget.item == null;

  @override
  void dispose() {
    for (final c in [_name, _unit, _quantity, _min, _location, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _unit.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the item name and its unit.')));
      return;
    }
    final repo = ref.read(inventoryRepositoryProvider);
    final churchId = ref.read(activeChurchIdProvider)!;
    final min = int.tryParse(_min.text.trim()) ?? 0;
    setState(() => _busy = true);
    try {
      if (_isNew) {
        await repo.addItem(
          churchId,
          name: _name.text.trim(),
          category: _category,
          unit: _unit.text.trim(),
          quantity: int.tryParse(_quantity.text.trim()) ?? 0,
          minLevel: min,
          location: _location.text.trim(),
          notes: _notes.text.trim(),
          byName: ref.read(authStateProvider).value?.displayName ?? '',
        );
      } else {
        await repo.updateItem(
          churchId,
          widget.item!.id,
          name: _name.text.trim(),
          category: _category,
          unit: _unit.text.trim(),
          minLevel: min,
          location: _location.text.trim(),
          notes: _notes.text.trim(),
          active: _active,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isNew ? 'Add an item' : 'Change item details', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            TextField(controller: _name, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Item name (for example Plastic chairs)')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final c in inventoryCategories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            Row(children: [
              if (_isNew) ...[
                Expanded(child: TextField(controller: _quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'How many now'))),
                const SizedBox(width: 10),
              ],
              Expanded(child: TextField(controller: _unit, decoration: const InputDecoration(labelText: 'Unit (pieces, boxes...)'))),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _min,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Warn me at this level or below', helperText: '0 means no warning'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _location, decoration: const InputDecoration(labelText: 'Where it is kept (optional)')),
            const SizedBox(height: 12),
            TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)')),
            if (!_isNew)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Still in use'),
                subtitle: const Text('Switch off for items sold, scrapped or no longer kept'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stock in, out, or a count ────────────────────────────────────────────
Future<void> showStockSheet(BuildContext context, InventoryItem item, StockKind kind) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _StockSheet(item: item, kind: kind),
);

class _StockSheet extends ConsumerStatefulWidget {
  const _StockSheet({required this.item, required this.kind});

  final InventoryItem item;
  final StockKind kind;

  @override
  ConsumerState<_StockSheet> createState() => _StockSheetState();
}

class _StockSheetState extends ConsumerState<_StockSheet> {
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  final _who = TextEditingController();
  late String _reason = stockReasons[widget.kind]!.first;
  bool _busy = false;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    _who.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final q = int.tryParse(_quantity.text.trim());
    if (q == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a whole number.')));
      return;
    }
    final lending = widget.kind == StockKind.taken && _reason == 'Lent out';
    final returning = widget.kind == StockKind.added && _reason == 'Returned';
    setState(() => _busy = true);
    try {
      await ref.read(inventoryRepositoryProvider).move(
        ref.read(activeChurchIdProvider)!,
        widget.item,
        kind: widget.kind,
        quantity: q,
        reason: _reason,
        note: _note.text.trim(),
        byName: ref.read(authStateProvider).value?.displayName ?? '',
        custodian: lending ? _who.text.trim() : (returning ? '' : null),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final counting = widget.kind == StockKind.counted;
    final lending = widget.kind == StockKind.taken && _reason == 'Lent out';
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.kind.label}: ${widget.item.name}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Now in stock: ${widget.item.quantity} ${widget.item.unit}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62))),
            const SizedBox(height: 14),
            TextField(
              controller: _quantity,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: counting ? 'How many are there now' : 'How many (${widget.item.unit})'),
            ),
            if (!counting) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _reason,
                decoration: const InputDecoration(labelText: 'Why'),
                items: [for (final r in stockReasons[widget.kind]!) DropdownMenuItem(value: r, child: Text(r))],
                onChanged: (v) => setState(() => _reason = v ?? _reason),
              ),
            ],
            if (lending) ...[
              const SizedBox(height: 12),
              TextField(controller: _who, decoration: const InputDecoration(labelText: 'Who is taking it')),
            ],
            const SizedBox(height: 12),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}