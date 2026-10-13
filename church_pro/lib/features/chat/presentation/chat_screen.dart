import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/chat_providers.dart';
import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/utils/formatters.dart';
import '../../team/domain/team_member.dart';
import '../domain/chat_models.dart';

/// One conversation.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.channelId});

  final String channelId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    final me = ref.read(authStateProvider).value;
    if (text.isEmpty || me == null) return;
    _text.clear();
    await ref.read(chatRepositoryProvider).send(
      ref.read(activeChurchIdProvider)!,
      widget.channelId,
      text: text,
      uid: me.uid,
      name: me.displayName,
    );
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authStateProvider).value;
    final channel = ref.watch(channelsProvider).value?.where((c) => c.id == widget.channelId).firstOrNull;
    final messages = ref.watch(channelMessagesProvider(widget.channelId));
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);

    if (channel == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(channel.titleFor(me?.uid ?? '')),
        actions: [
          if (!channel.isDm)
            IconButton(
              tooltip: 'Who is in this group',
              icon: const Icon(Icons.groups_2_outlined),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _MembersSheet(channel: channel),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) {
                if (list.isEmpty) {
                  return Center(child: Text('No messages yet. Say hello.', style: TextStyle(color: muted)));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final m = list[i];
                    final older = i + 1 < list.length ? list[i + 1] : null;
                    final mine = m.authorUid == me?.uid;
                    return Column(
                      children: [
                        if (older == null || !_sameDay(older.createdAt, m.createdAt))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(formatDate(m.createdAt), style: TextStyle(color: muted, fontSize: 12)),
                          ),
                        Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                              decoration: BoxDecoration(
                                color: mine ? scheme.primary.withValues(alpha: 0.12) : scheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: scheme.outlineVariant),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!mine && !channel.isDm)
                                    Text(m.authorName, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary, fontSize: 12)),
                                  SelectableText(m.text),
                                  const SizedBox(height: 2),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(formatTime(m.createdAt), style: TextStyle(color: muted, fontSize: 10)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Write a message'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(tooltip: 'Send', onPressed: _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Who is in a group. The admin can change it.
class _MembersSheet extends ConsumerStatefulWidget {
  const _MembersSheet({required this.channel});

  final Channel channel;

  @override
  ConsumerState<_MembersSheet> createState() => _MembersSheetState();
}

class _MembersSheetState extends ConsumerState<_MembersSheet> {
  late final Set<String> _selected = {...widget.channel.members};

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(currentRoleProvider) == ChurchRole.admin;
    final me = ref.watch(authStateProvider).value;
    final team = ref.watch(teamProvider).value ?? const <TeamMember>[];
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.channel.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('${widget.channel.members.length} people', style: TextStyle(color: muted)),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (isAdmin)
                  for (final p in team.where((m) => m.active))
                    CheckboxListTile(
                      value: _selected.contains(p.uid),
                      title: Text(p.name),
                      subtitle: Text(p.title.isEmpty ? p.role.label : '${p.title} (${p.role.label})'),
                      onChanged: p.uid == me?.uid ? null : (v) => setState(() => v == true ? _selected.add(p.uid) : _selected.remove(p.uid)),
                    )
                else
                  for (final id in widget.channel.members) ListTile(title: Text(widget.channel.memberNames[id] ?? 'Member')),
              ],
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () async {
                final names = {
                  for (final p in team)
                    if (_selected.contains(p.uid)) p.uid: p.name,
                  if (me != null) me.uid: me.displayName,
                };
                await ref.read(chatRepositoryProvider).updateMembers(ref.read(activeChurchIdProvider)!, widget.channel.id, names);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save members'),
            ),
          ],
        ],
      ),
    );
  }
}