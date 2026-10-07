import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/widgets/permission_gate.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final canEdit = Permissions.can(ref.watch(currentRoleProvider), Permission.manageMembers);
    final members = ref.watch(membersProvider);

    return PermissionGate(
      permission: Permission.viewMembers,
      child: Scaffold(
        floatingActionButton: canEdit
            ? FloatingActionButton(
                tooltip: 'Add member',
                onPressed: () => context.push('/members/form'),
                child: const Icon(Icons.person_add),
              )
            : null,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search members'),
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
              ),
            ),
            Expanded(
              child: members.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (all) {
                  final list = all
                      .where((m) => m.fullName.toLowerCase().contains(_query) || m.phone.contains(_query))
                      .toList()
                    ..sort((a, b) => a.fullName.compareTo(b.fullName));
                  if (list.isEmpty) return const Center(child: Text('No members found'));
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final m = list[i];
                      return ListTile(
                        leading: CircleAvatar(child: Text(m.firstName.isEmpty ? '?' : m.firstName[0])),
                        title: Text(m.fullName),
                        subtitle: Text(m.phone.isEmpty ? m.status.name : '${m.phone} · ${m.status.name}'),
                        onTap: canEdit ? () => context.push('/members/form', extra: m) : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
