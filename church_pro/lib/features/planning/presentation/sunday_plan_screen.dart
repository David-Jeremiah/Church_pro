import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/planning_providers.dart';
import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/planning_models.dart';
import 'service_pattern_sheet.dart';

/// Plan one Sunday: separate services or one joint service, and who preaches and leads.
class SundayPlanScreen extends ConsumerStatefulWidget {
  const SundayPlanScreen({super.key, required this.date});

  final DateTime date;

  @override
  ConsumerState<SundayPlanScreen> createState() => _SundayPlanScreenState();
}

class _SundayPlanScreenState extends ConsumerState<SundayPlanScreen> {
  final _preachers = <TextEditingController>[];
  final _leaders = <TextEditingController>[];
  final _jointPreacher = TextEditingController();
  final _jointLeader = TextEditingController();
  final _jointTime = TextEditingController();
  List<ServiceSlot> _slots = const [];
  bool _joint = false;
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [..._preachers, ..._leaders, _jointPreacher, _jointLeader, _jointTime]) {
      c.dispose();
    }
    super.dispose();
  }

  void _say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _init(List<PlannedService> all, List<ServiceSlot> pattern) {
    final existing = all.where((s) => sameDay(s.date, widget.date)).toList();
    _slots = pattern;
    for (var i = 0; i < pattern.length; i++) {
      _preachers.add(TextEditingController());
      _leaders.add(TextEditingController());
    }
    if (existing.isNotEmpty && existing.first.isJoint) {
      final j = existing.first;
      _joint = true;
      _jointTime.text = j.time;
      _jointPreacher.text = j.preacher;
      _jointLeader.text = j.leader;
    } else {
      for (var i = 0; i < pattern.length; i++) {
        final match = existing.where((e) => e.order == i);
        if (match.isNotEmpty) {
          _preachers[i].text = match.first.preacher;
          _leaders[i].text = match.first.leader;
        }
      }
    }
    if (_jointTime.text.isEmpty && pattern.isNotEmpty) _jointTime.text = pattern.first.time;
    _loaded = true;
  }

  Future<void> _save() async {
    final churchId = ref.read(activeChurchIdProvider);
    if (churchId == null) return;
    final day = DateTime(widget.date.year, widget.date.month, widget.date.day);
    final services = _joint
        ? [
      PlannedService(
        date: day,
        name: 'Joint service',
        time: _jointTime.text.trim(),
        preacher: _jointPreacher.text.trim(),
        leader: _jointLeader.text.trim(),
        isJoint: true,
      ),
    ]
        : [
      for (var i = 0; i < _slots.length; i++)
        PlannedService(
          date: day,
          name: _slots[i].name,
          time: _slots[i].time,
          preacher: _preachers[i].text.trim(),
          leader: _leaders[i].text.trim(),
        ),
    ];

    setState(() => _busy = true);
    try {
      await ref.read(planningRepositoryProvider).savePlan(churchId, day, services);
      if (!mounted) return;
      _say('Plan saved');
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/attendance');
      }
    } catch (_) {
      if (mounted) _say('Could not save the plan. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planned = ref.watch(plannedServicesProvider);
    final pattern = ref.watch(servicePatternProvider);
    final canEdit = ref.watch(canProvider(Permission.manageServices));
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);

    if (!_loaded && planned.hasValue && pattern.hasValue) _init(planned.value!, pattern.value!);

    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Plan a Sunday')),
        body: Center(
          child: planned.hasError || pattern.hasError
              ? const Text('Could not load the plan.')
              : const CircularProgressIndicator(),
        ),
      );
    }

    Widget serviceCard(String title, TextEditingController preacher, TextEditingController leader) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 12),
              TextField(
                controller: preacher,
                enabled: canEdit,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Preacher', prefixIcon: Icon(Icons.record_voice_over_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: leader,
                enabled: canEdit,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Service leader', prefixIcon: Icon(Icons.person_outline)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Plan a Sunday')),
      body: ContentWidth(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            Text(formatDate(widget.date), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Separate services')),
                ButtonSegment(value: true, label: Text('Joint service')),
              ],
              selected: {_joint},
              onSelectionChanged: canEdit ? (s) => setState(() => _joint = s.first) : null,
            ),
            const SizedBox(height: 12),
            if (_joint) ...[
              TextField(
                controller: _jointTime,
                enabled: canEdit,
                decoration: const InputDecoration(labelText: 'Time', prefixIcon: Icon(Icons.schedule)),
              ),
              const SizedBox(height: 12),
              serviceCard('Joint service', _jointPreacher, _jointLeader),
            ] else
              for (var i = 0; i < _slots.length; i++)
                serviceCard(
                  _slots[i].time.isEmpty ? _slots[i].name : '${_slots[i].name}, ${_slots[i].time}',
                  _preachers[i],
                  _leaders[i],
                ),
            if (canEdit) ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const Text('Save the plan'),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showServicePatternSheet(context),
                  icon: const Icon(Icons.schedule),
                  label: const Text('Change service names and times'),
                ),
              ),
              Text(
                'Changing the names and times applies the next time you open a Sunday plan.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Only people who manage services can change the plan.',
                    style: TextStyle(color: muted, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}