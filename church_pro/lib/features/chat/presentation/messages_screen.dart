import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/chat_providers.dart';
import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../team/domain/team_member.dart';
import '../domain/chat_models.dart';

/// Church chat: direct messages, and groups the admin sets up.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  String _when(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    return (t.year == now.year && t.month == now.month && t.day == now.day) ? formatTime(t) : formatDate(t);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(channelsProvider);
    final me = ref.watch(authStateProvider).value;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _NewMessageSheet(),
        ),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('New message'),
      ),
      body: channels.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.forum_outlined,
                title: 'No conversations yet',
                message: 'Tap "New message" to write to someone on the team.',
              ),
            );
          }
          return ContentWidth(
            maxWidth: 800,
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (_, i) {
                final c = list[i];
                final title = c.titleFor(me?.uid ?? '');
                final mine = c.lastBy == me?.displayName;
                return ListTile(
                  leading: c.isDm
                      ? InitialAvatar(title, size: 44)
                      : Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.forest.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.groups_2_outlined, color: AppColors.forest),
                  ),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    c.lastMessage.isEmpty ? 'No messages yet' : '${mine ? 'You' : c.lastBy}: ${c.lastMessage}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted),
                  ),
                  trailing: Text(_when(c.lastAt), style: TextStyle(color: muted, fontSize: 12)),
                  onTap: () => context.push('/messages/${c.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NewMessageSheet extends ConsumerStatefulWidget {
  const _NewMessageSheet();

  @override
  ConsumerState<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends ConsumerState<_NewMessageSheet> {
  String _query = '';
  bool _group = false;
  final _groupName = TextEditingController();
  final _picked = <String>{};
  bool _busy = false;

  @override
  void dispose() {
    _groupName.dispose();
    super.dispose();
  }

  Future<void> _open(TeamMember person) async {
    final me = ref.read(authStateProvider).value!;
    final id = await ref.read(chatRepositoryProvider).openDirect(
      ref.read(activeChurchIdProvider)!,
      myUid: me.uid,
      myName: me.displayName,
      otherUid: person.uid,
      otherName: person.name,
    );
    if (!mounted) return;
    Navigator.pop(context);
    context.push('/messages/$id');
  }

  Future<void> _createGroup(List<TeamMember> people) async {
    final me = ref.read(authStateProvider).value!;
    if (_groupName.text.trim().isEmpty || _picked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give the group a name and choose who is in it.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final chosen = {
        me.uid: me.displayName,
        for (final p in people)
          if (_picked.contains(p.uid)) p.uid: p.name,
      };
      final id = await ref.read(chatRepositoryProvider).createGroup(
        ref.read(activeChurchIdProvider)!,
        name: _groupName.text.trim(),
        myUid: me.uid,
        people: chosen,
      );
      if (!mounted) return;
      Navigator.pop(context);
      context.push('/messages/$id');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authStateProvider).value;
    final isAdmin = ref.watch(currentRoleProvider) == ChurchRole.admin;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    final people = (ref.watch(teamProvider).value ?? const <TeamMember>[])
        .where((m) => m.active && m.uid != me?.uid && m.name.toLowerCase().contains(_query))
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_group ? 'New group' : 'New message', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (isAdmin)
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Direct message'), icon: Icon(Icons.person_outline)),
                ButtonSegment(value: true, label: Text('Group'), icon: Icon(Icons.groups_2_outlined)),
              ],
              selected: {_group},
              onSelectionChanged: (s) => setState(() => _group = s.first),
            ),
          if (_group) ...[
            const SizedBox(height: 12),
            TextField(controller: _groupName, decoration: const InputDecoration(labelText: 'Group name (for example Pastors)')),
          ],
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(hintText: 'Search the team', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: people.isEmpty
                ? Padding(padding: const EdgeInsets.all(20), child: Text('No one found.', style: TextStyle(color: muted)))
                : ListView(
              shrinkWrap: true,
              children: [
                for (final p in people)
                  _group
                      ? CheckboxListTile(
                    value: _picked.contains(p.uid),
                    title: Text(p.name),
                    subtitle: Text(p.title.isEmpty ? p.role.label : '${p.title} (${p.role.label})'),
                    onChanged: (v) => setState(() => v == true ? _picked.add(p.uid) : _picked.remove(p.uid)),
                  )
                      : ListTile(
                    leading: InitialAvatar(p.name, size: 38),
                    title: Text(p.name),
                    subtitle: Text(p.title.isEmpty ? p.role.label : '${p.title} (${p.role.label})'),
                    onTap: () => _open(p),
                  ),
              ],
            ),
          ),
          if (_group) ...[
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _busy ? null : () => _createGroup(people),
              child: const Text('Create group'),
            ),
          ],
        ],
      ),
    );
  }
}