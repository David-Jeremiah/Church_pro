import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../domain/member.dart';

class MemberFormScreen extends ConsumerStatefulWidget {
  const MemberFormScreen({super.key, this.member});

  final Member? member;

  @override
  ConsumerState<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends ConsumerState<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _first = TextEditingController(text: widget.member?.firstName);
  late final _last = TextEditingController(text: widget.member?.lastName);
  late final _phone = TextEditingController(text: widget.member?.phone);
  late final _email = TextEditingController(text: widget.member?.email);
  late MembershipStatus _status = widget.member?.status ?? MembershipStatus.member;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final churchId = ref.read(activeChurchIdProvider)!;
    final base = widget.member ?? const Member(id: '', firstName: '', lastName: '');
    await ref.read(memberRepositoryProvider).save(
          churchId,
          base.copyWith(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            status: _status,
          ),
        );
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete member?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(memberRepositoryProvider).delete(ref.read(activeChurchIdProvider)!, widget.member!.id);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.member == null ? 'New member' : 'Edit member'),
        actions: [
          if (widget.member != null) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _first,
              decoration: const InputDecoration(labelText: 'First name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _last,
              decoration: const InputDecoration(labelText: 'Last name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MembershipStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                for (final s in MembershipStatus.values) DropdownMenuItem(value: s, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
