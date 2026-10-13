import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/planning_providers.dart';
import '../../../app/providers.dart';
import '../domain/planning_models.dart';

/// Edit the church's usual Sunday services, e.g. 1st service 7:00 AM, 2nd 9:30 AM.
Future<void> showServicePatternSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _ServicePatternSheet(),
  );
}

class _ServicePatternSheet extends ConsumerStatefulWidget {
  const _ServicePatternSheet();

  @override
  ConsumerState<_ServicePatternSheet> createState() => _ServicePatternSheetState();
}

class _ServicePatternSheetState extends ConsumerState<_ServicePatternSheet> {
  static const _maxServices = 5;

  final _names = <TextEditingController>[];
  final _times = <TextEditingController>[];
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [..._names, ..._times]) {
      c.dispose();
    }
    super.dispose();
  }

  void _add(String name, String time) {
    _names.add(TextEditingController(text: name));
    _times.add(TextEditingController(text: time));
  }

  void _say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _save() async {
    final churchId = ref.read(activeChurchIdProvider);
    if (churchId == null) return;
    final slots = <ServiceSlot>[
      for (var i = 0; i < _names.length; i++)
        if (_names[i].text.trim().isNotEmpty)
          ServiceSlot(name: _names[i].text.trim(), time: _times[i].text.trim()),
    ];
    if (slots.isEmpty) {
      _say('Add at least one service.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(planningRepositoryProvider).savePattern(churchId, slots);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _say('Could not save. Check your connection and try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pattern = ref.watch(servicePatternProvider);
    if (!_loaded && pattern.hasValue) {
      for (final s in pattern.value!) {
        _add(s.name, s.time);
      }
      _loaded = true;
    }

    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    if (!_loaded) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service names and times', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'These are the services offered on a normal Sunday.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62), fontSize: 12),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < _names.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _names[i],
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _times[i],
                        decoration: const InputDecoration(labelText: 'Time'),
                      ),
                    ),
                    if (_names.length > 1)
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _names.removeAt(i).dispose();
                          _times.removeAt(i).dispose();
                        }),
                      ),
                  ],
                ),
              ),
            if (_names.length < _maxServices)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _add('${_names.length + 1}th service', '')),
                  icon: const Icon(Icons.add),
                  label: const Text('Add a service'),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}