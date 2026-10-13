import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/utils/password_generator.dart';
import '../../../core/widgets/credentials_dialog.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../core/widgets/prompt_dialog.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/team_member.dart';

/// Church admin creates logins for the accountant, pastors, staff and leaders,
/// and gives each person a role and a title (for example "Youth pastor").
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(teamProvider);
    final myUid = ref.watch(authStateProvider).value?.uid;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);

    return Scaffold(
      appBar: AppBar(title: const Text('Team and logins')),
      floatingActionButton: PermissionGate(
        permission: Permission.manageUsers,
        fallback: const SizedBox.shrink(),
        child: FloatingActionButton.extended(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _AddLoginSheet(),
          ),
          icon: const Icon(Icons.person_add),
          label: const Text('Add a login'),
        ),
      ),
      body: PermissionGate(
        permission: Permission.manageUsers,
        child: team.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (list) => ListView.separated(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (_, i) {
              final m = list[i];
              final locked = m.role == ChurchRole.admin || m.uid == myUid;
              return ListTile(
                leading: CircleAvatar(child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase())),
                title: Text(m.name),
                subtitle: Text(
                  m.title.isEmpty ? m.email : '${m.title}.  ${m.email}',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusChip(m.role.label),
                    const SizedBox(width: 4),
                    if (!m.active) const StatusChip('Inactive', color: Colors.red),
                    if (!locked) _MemberMenu(member: m),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MemberMenu extends ConsumerWidget {
  const _MemberMenu({required this.member});

  final TeamMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final churchId = ref.read(activeChurchIdProvider)!;
    final repo = ref.read(teamRepositoryProvider);
    return PopupMenuButton<String>(
      onSelected: (v) async {
        if (v == 'toggle') {
          await repo.setActive(churchId, member.uid, !member.active);
        } else if (v == 'title') {
          final title = await promptText(context, title: 'Title for ${member.name}', label: 'For example: Youth pastor');
          if (title != null) await repo.setTitle(churchId, member.uid, title);
        } else if (v == 'reset') {
          await ref.read(authRepositoryProvider).sendPasswordReset(member.email);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reset link sent to ${member.email}')));
          }
        } else if (v.startsWith('role:')) {
          await repo.setRole(churchId, member.uid, ChurchRole.fromName(v.substring(5)));
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'title', child: Text('Set a title (for example Youth pastor)')),
        for (final r in Permissions.assignableRoles)
          if (r != member.role) PopupMenuItem(value: 'role:${r.name}', child: Text('Make ${r.label}')),
        PopupMenuItem(value: 'toggle', child: Text(member.active ? 'Deactivate login' : 'Activate login')),
        const PopupMenuItem(value: 'reset', child: Text('Send password reset')),
      ],
    );
  }
}

class _AddLoginSheet extends ConsumerStatefulWidget {
  const _AddLoginSheet();

  @override
  ConsumerState<_AddLoginSheet> createState() => _AddLoginSheetState();
}

class _AddLoginSheetState extends ConsumerState<_AddLoginSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController(text: generatePassword());
  ChurchRole _role = ChurchRole.staff;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final membership = ref.read(activeMembershipProvider);
    final admin = ref.read(authStateProvider).value;
    if (membership == null || admin == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(teamRepositoryProvider).createLogin(
        adminUid: admin.uid,
        churchId: membership.churchId,
        churchName: membership.churchName,
        name: _name.text.trim(),
        email: _email.text.trim(),
        role: _role,
        tempPassword: _password.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      await showCredentials(
        context,
        title: 'Login created for ${_name.text.trim()}',
        email: _email.text.trim(),
        password: _password.text,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _roleHelp => switch (_role) {
    ChurchRole.accountant => 'Keeps the books, prepares budgets, orders and pays.',
    ChurchRole.leadPastor => 'Approves budgets the admin sends, and sees the yearly reports.',
    ChurchRole.pastor => 'Sees only the budgets that are shared with them.',
    ChurchRole.staff => 'Office work and records.',
    ChurchRole.leader => 'Marks attendance and requests purchases.',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add a login', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email (used to sign in)'),
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ChurchRole>(
                initialValue: _role,
                decoration: InputDecoration(labelText: 'Role', helperText: _roleHelp),
                items: [
                  for (final r in Permissions.assignableRoles) DropdownMenuItem(value: r, child: Text(r.label)),
                ],
                onChanged: (v) => setState(() => _role = v ?? _role),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                decoration: InputDecoration(
                  labelText: 'Temporary password',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() => _password.text = generatePassword()),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const Text('Create login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}