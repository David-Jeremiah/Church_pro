import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/permission_gate.dart';
import '../domain/work_log.dart';

/// Staff record where they worked each day (office, home or field) so the
/// church can support remote work and see who is where.
class WorkScreen extends ConsumerWidget {
  const WorkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(canProvider(Permission.viewTeamWork));
    return PermissionGate(
      permission: Permission.logWork,
      child: DefaultTabController(
        key: ValueKey(team),
        length: team ? 2 : 1,
        child: Column(
          children: [
            TabBar(tabs: [const Tab(text: 'My work'), if (team) const Tab(text: 'Team')]),
            Expanded(child: TabBarView(children: [const _MyWork(), if (team) const _TeamWork()])),
          ],
        ),
      ),
    );
  }
}

String _modeCounts(Iterable<WorkLog> logs) {
  int n(WorkMode m) => logs.where((l) => l.mode == m).length;
  return 'Office ${n(WorkMode.office)} · Home ${n(WorkMode.home)}';
}

class _MyWork extends ConsumerWidget {
  const _MyWork();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(myWorkLogsProvider).value ?? const <WorkLog>[];
    final since = dayKey(DateTime.now().subtract(const Duration(days: 30)));
    final recent = logs.where((l) => l.date.compareTo(since) >= 0);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _TodayCard(),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Last 30 days'),
            subtitle: Text(_modeCounts(recent)),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.edit_calendar),
            label: const Text('Log a day I forgot'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _PastDaySheet(),
            ),
          ),
        ),
        for (final l in logs)
          ListTile(
            leading: Icon(l.mode.icon),
            title: Text('${formatDate(DateTime.parse(l.date))} · ${l.mode.label}'),
            subtitle: Text(l.notes.isEmpty ? '—' : l.notes),
            trailing: Text(l.worked == null ? 'In progress' : formatDuration(l.worked!)),
          ),
      ],
    );
  }
}

class _TodayCard extends ConsumerStatefulWidget {
  const _TodayCard();

  @override
  ConsumerState<_TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends ConsumerState<_TodayCard> {
  WorkMode _mode = WorkMode.office;
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayWorkLogProvider);
    final user = ref.watch(authStateProvider).value;
    final churchId = ref.watch(activeChurchIdProvider);
    final repo = ref.read(workRepositoryProvider);

    Widget body;
    if (today == null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Where are you working today?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<WorkMode>(
            segments: [
              for (final m in WorkMode.values) ButtonSegment(value: m, label: Text(m.label), icon: Icon(m.icon)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.login),
            label: const Text('Clock in'),
            onPressed: _busy || user == null || churchId == null
                ? null
                : () => _run(() => repo.clockIn(churchId, uid: user.uid, name: user.displayName, mode: _mode)),
          ),
        ],
      );
    } else if (today.isOpen) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(today.mode.icon),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Working from ${today.mode.label.toLowerCase()} since ${formatTime(today.clockIn)}',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'What did you work on today?'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.logout),
            label: const Text('Clock out'),
            onPressed: _busy || churchId == null ? null : () => _run(() => repo.clockOut(churchId, today, _notes.text.trim())),
          ),
        ],
      );
    } else {
      body = Row(children: [
        const Icon(Icons.check_circle, color: Colors.green),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Done for today: ${formatDuration(today.worked!)} from ${today.mode.label.toLowerCase()}',
              style: Theme.of(context).textTheme.titleMedium),
        ),
      ]);
    }

    return Card(child: Padding(padding: const EdgeInsets.all(16), child: body));
  }
}

class _PastDaySheet extends ConsumerStatefulWidget {
  const _PastDaySheet();

  @override
  ConsumerState<_PastDaySheet> createState() => _PastDaySheetState();
}

class _PastDaySheetState extends ConsumerState<_PastDaySheet> {
  DateTime _day = DateTime.now().subtract(const Duration(days: 1));
  WorkMode _mode = WorkMode.office;
  final _hours = TextEditingController(text: '8');
  final _notes = TextEditingController();

  @override
  void dispose() {
    _hours.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final hours = double.tryParse(_hours.text.trim());
    final user = ref.read(authStateProvider).value;
    final churchId = ref.read(activeChurchIdProvider);
    if (hours == null || hours <= 0 || hours > 16 || user == null || churchId == null) return;
    await ref.read(workRepositoryProvider).logPastDay(
      churchId,
      uid: user.uid,
      name: user.displayName,
      day: _day,
      mode: _mode,
      hours: hours,
      notes: _notes.text.trim(),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Log a day', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(formatDate(_day)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _day,
                  firstDate: DateTime.now().subtract(const Duration(days: 60)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _day = picked);
              },
            ),
            const SizedBox(height: 12),
            SegmentedButton<WorkMode>(
              segments: [for (final m in WorkMode.values) ButtonSegment(value: m, label: Text(m.label), icon: Icon(m.icon))],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hours,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Hours worked'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'What did you work on?')),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}

class _TeamWork extends ConsumerWidget {
  const _TeamWork();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = (ref.watch(teamProvider).value ?? const [])
        .where((m) => m.active && Permissions.can(m.role, Permission.logWork))
        .toList();
    final logs = ref.watch(teamWorkLogsProvider).value ?? const <WorkLog>[];
    final today = dayKey(DateTime.now());

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.groups),
            title: const Text('Today'),
            subtitle: Text(
              '${_modeCounts(logs.where((l) => l.date == today))} · Not in ${team.where((m) => !logs.any((l) => l.uid == m.uid && l.date == today)).length}',
            ),
          ),
        ),
        for (final m in team)
          Builder(builder: (_) {
            final mine = logs.where((l) => l.uid == m.uid).toList();
            final todayLog = mine.where((l) => l.date == today).firstOrNull;
            final status = todayLog == null
                ? 'Not clocked in'
                : '${todayLog.mode.label}${todayLog.isOpen ? ' · since ${formatTime(todayLog.clockIn)}' : ' · done (${formatDuration(todayLog.worked!)})'}';
            return ListTile(
              leading: Icon(todayLog?.mode.icon ?? Icons.person_off_outlined),
              title: Text('${m.name} · ${m.role.label}'),
              subtitle: Text('$status\nLast 31 days: ${_modeCounts(mine)}'),
              isThreeLine: true,
            );
          }),
        if (team.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No staff logins yet. Add them under Team & logins.')),
      ],
    );
  }
}