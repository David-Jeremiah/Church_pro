import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/password_generator.dart';
import '../../../core/widgets/credentials_dialog.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/ui_kit.dart';
import '../data/platform_repository.dart';

final platformAdminsProvider = StreamProvider<List<PlatformAdmin>>(
      (ref) => ref.watch(platformRepositoryProvider).watchAdmins(),
);

/// Add or remove other platform admins (people who run the whole system).
class PlatformAdminsScreen extends ConsumerWidget {
  const PlatformAdminsScreen({super.key});

  Future<void> _remove(BuildContext context, WidgetRef ref, PlatformAdmin a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${a.name}?'),
        content: const Text('They will no longer be able to manage churches. Their login is not deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(platformRepositoryProvider).removeAdmin(a.uid);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admins = ref.watch(platformAdminsProvider);
    final me = ref.watch(authStateProvider).value?.uid;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);

    return Scaffold(
      appBar: AppBar(title: const Text('Platform admins')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _AddAdminSheet(),
        ),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add an admin'),
      ),
      body: admins.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => ContentWidth(
          maxWidth: 800,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
                child: Text(
                  'Platform admins add churches and church administrators. '
                      'They cannot see any church\'s members, money or work logs.',
                  style: TextStyle(color: muted),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const Divider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                        child: Row(
                          children: [
                            InitialAvatar(list[i].name, size: 44),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(list[i].name.isEmpty ? 'Admin' : list[i].name,
                                      style: Theme.of(context).textTheme.titleSmall),
                                  if (list[i].email.isNotEmpty)
                                    Text(list[i].email, style: TextStyle(color: muted, fontSize: 13)),
                                ],
                              ),
                            ),
                            if (list[i].uid == me)
                              const StatusChip('You')
                            else
                              IconButton(
                                tooltip: 'Remove admin rights',
                                icon: const Icon(Icons.person_remove_outlined),
                                onPressed: () => _remove(context, ref, list[i]),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddAdminSheet extends ConsumerStatefulWidget {
  const _AddAdminSheet();

  @override
  ConsumerState<_AddAdminSheet> createState() => _AddAdminSheetState();
}

class _AddAdminSheetState extends ConsumerState<_AddAdminSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController(text: generatePassword());
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
    final me = ref.read(authStateProvider).value;
    if (me == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(platformRepositoryProvider).addAdmin(
        byUid: me.uid,
        name: _name.text.trim(),
        email: _email.text.trim(),
        tempPassword: _password.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      await showCredentials(
        context,
        title: '${_name.text.trim()} is now a platform admin',
        email: _email.text.trim(),
        password: _password.text,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
              Text('Add a platform admin', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
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
              TextFormField(
                controller: _password,
                decoration: InputDecoration(
                  labelText: 'Temporary password',
                  helperText: 'They must change it at first sign-in',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() => _password.text = generatePassword()),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const Text('Create admin login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}