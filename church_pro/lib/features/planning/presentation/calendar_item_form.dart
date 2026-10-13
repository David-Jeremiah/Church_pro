import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/planning_providers.dart';
import '../../../app/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/planning_models.dart';

/// Add or edit a date worth remembering. Pass [item] to edit, leave it null to add.
class CalendarItemForm extends ConsumerStatefulWidget {
  const CalendarItemForm({super.key, this.item});

  final CalendarItem? item;

  @override
  ConsumerState<CalendarItemForm> createState() => _CalendarItemFormState();
}

class _CalendarItemFormState extends ConsumerState<CalendarItemForm> {
  late final _title = TextEditingController(text: widget.item?.title ?? '');
  late final _time = TextEditingController(text: widget.item?.time ?? '');
  late final _notes = TextEditingController(text: widget.item?.notes ?? '');
  late DateTime _date = widget.item?.date ?? DateTime.now();
  late CalendarKind _kind = widget.item?.kind ?? CalendarKind.event;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_title, _time, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/attendance');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final churchId = ref.read(activeChurchIdProvider);
    if (churchId == null) return;
    if (_title.text.trim().isEmpty) {
      _say('Give it a name first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(planningRepositoryProvider).saveItem(
        churchId,
        CalendarItem(
          id: widget.item?.id ?? '',
          title: _title.text.trim(),
          date: _date,
          time: _time.text.trim(),
          kind: _kind,
          notes: _notes.text.trim(),
        ),
      );
      if (mounted) {
        _say('Saved');
        _leave();
      }
    } catch (_) {
      if (mounted) _say('Could not save. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final churchId = ref.read(activeChurchIdProvider);
    final id = widget.item?.id ?? '';
    if (churchId == null || id.isEmpty) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this date?'),
        content: Text('"${widget.item!.title}" will be removed from the calendar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(planningRepositoryProvider).deleteItem(churchId, id);
      if (mounted) _leave();
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _say('Could not delete. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit date' : 'Add a date')),
      body: ContentWidth(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in CalendarKind.values)
                  ChoiceChip(
                    avatar: Icon(k.icon, size: 18),
                    label: Text(k.label),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(formatDate(_date)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _time,
              decoration: const InputDecoration(labelText: 'Time (optional)', hintText: 'For example 4:00 PM'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : const Text('Save'),
            ),
            if (editing) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete this date'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}