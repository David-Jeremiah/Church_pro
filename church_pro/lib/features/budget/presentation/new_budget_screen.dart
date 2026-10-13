import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../team/domain/team_member.dart';

/// Create a budget as a draft and choose who may see it while it is prepared.
class NewBudgetScreen extends ConsumerStatefulWidget {
  const NewBudgetScreen({super.key});

  @override
  ConsumerState<NewBudgetScreen> createState() => _NewBudgetScreenState();
}

class _NewBudgetScreenState extends ConsumerState<NewBudgetScreen> {
  late final _name = TextEditingController(text: 'Budget ${DateTime.now().year + 1}');
  late int _year = DateTime.now().year + 1;
  final _shared = <String>{};
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final user = ref.read(authStateProvider).value;
    final churchId = ref.read(activeChurchIdProvider);
    if (_name.text.trim().isEmpty || user == null || churchId == null) return;
    setState(() => _busy = true);
    try {
      final id = await ref.read(budgetRepositoryProvider).createBudget(
        churchId,
        name: _name.text.trim(),
        year: _year,
        sharedWith: _shared.toList(),
        byName: user.displayName,
      );
      if (mounted) context.pushReplacement('/finance/budget/$id');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);
    final thisYear = DateTime.now().year;

    // Admin, accountant and lead pastor always see every budget, so only offer the others.
    final people = (ref.watch(teamProvider).value ?? const <TeamMember>[])
        .where((m) => m.active && const [ChurchRole.pastor, ChurchRole.leader, ChurchRole.staff].contains(m.role))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Create a budget')),
      body: ContentWidth(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Budget name')),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              initialValue: _year,
              decoration: const InputDecoration(labelText: 'Year'),
              items: [for (var y = thisYear - 1; y <= thisYear + 3; y++) DropdownMenuItem(value: y, child: Text('$y'))],
              onChanged: (v) => setState(() => _year = v ?? _year),
            ),
            const SectionTitle('Who can see it while you prepare it?'),
            Text(
              'The admin, the accountant and the lead pastor always see it. '
                  'Choose any other people who should be able to read it and comment, '
                  'for example the pastor in charge of that ministry.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 10),
            if (people.isEmpty)
              Text('No other pastors, leaders or staff have logins yet. You can share it later.',
                  style: TextStyle(color: muted))
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
                    for (var i = 0; i < people.length; i++) ...[
                      if (i > 0) const Divider(),
                      CheckboxListTile(
                        value: _shared.contains(people[i].uid),
                        title: Text(people[i].name),
                        subtitle: Text(people[i].title.isEmpty ? people[i].role.label : '${people[i].title} (${people[i].role.label})'),
                        onChanged: (v) => setState(() => v == true ? _shared.add(people[i].uid) : _shared.remove(people[i].uid)),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _create,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : const Text('Create budget'),
            ),
          ],
        ),
      ),
    );
  }
}