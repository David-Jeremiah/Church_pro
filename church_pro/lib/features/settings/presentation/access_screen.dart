import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/access.dart';
import '../../../core/constants/roles.dart';
import '../../../core/widgets/ui_kit.dart';

/// The church admin decides which roles see each part of the app.
class AccessScreen extends ConsumerStatefulWidget {
  const AccessScreen({super.key});

  @override
  ConsumerState<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends ConsumerState<AccessScreen> {
  Map<AccessModule, Set<ChurchRole>>? _choice;
  bool _busy = false;

  // The admin always keeps access, so only the other roles are shown.
  static const _roles = [
    ChurchRole.accountant,
    ChurchRole.leadPastor,
    ChurchRole.pastor,
    ChurchRole.leader,
    ChurchRole.staff,
    ChurchRole.member,
  ];

  Map<AccessModule, Set<ChurchRole>> _start(Map<String, List<String>> saved) => {
    for (final m in AccessModule.values)
      m: saved[m.name] != null
          ? {for (final n in saved[m.name]!) ChurchRole.fromName(n)}
          : {...m.defaultRoles},
  };

  Future<void> _save() async {
    final choice = _choice;
    if (choice == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(settingsRepositoryProvider).saveAccess(ref.read(activeChurchIdProvider)!, {
        for (final e in choice.entries) e.key.name: ['admin', ...e.value.where((r) => r != ChurchRole.admin).map((r) => r.name)],
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    await ref.read(settingsRepositoryProvider).resetAccess(ref.read(activeChurchIdProvider)!);
    if (mounted) setState(() => _choice = null);
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(accessProvider);
    if (!saved.hasValue) return Scaffold(appBar: AppBar(title: const Text('Who can see what')), body: const Center(child: CircularProgressIndicator()));
    final choice = _choice ??= _start(saved.value!);
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);

    return Scaffold(
      appBar: AppBar(title: const Text('Who can see what')),
      body: ContentWidth(
        maxWidth: 800,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            Text(
              'Choose which roles see each part of the app. You, the admin, always see everything. '
                  'The ledger, individual giving and budget approvals follow fixed finance rules and are not listed here.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 12),
            for (final m in AccessModule.values)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(m.icon),
                        const SizedBox(width: 10),
                        Expanded(child: Text(m.label, style: Theme.of(context).textTheme.titleSmall)),
                      ]),
                      const SizedBox(height: 4),
                      Text(m.description, style: TextStyle(color: muted, fontSize: 12)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final r in _roles)
                            FilterChip(
                              label: Text(r.label),
                              selected: choice[m]!.contains(r),
                              onSelected: (on) => setState(() => on ? choice[m]!.add(r) : choice[m]!.remove(r)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                        : const Text('Save'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(onPressed: _reset, child: const Text('Back to the usual setup')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}