import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/utils/password_generator.dart';
import '../../../core/widgets/credentials_dialog.dart';

/// Platform admin adds a church and creates the church administrator's login.
class AddChurchScreen extends ConsumerStatefulWidget {
  const AddChurchScreen({super.key});

  @override
  ConsumerState<AddChurchScreen> createState() => _AddChurchScreenState();
}

class _AddChurchScreenState extends ConsumerState<AddChurchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _church = TextEditingController();
  final _country = TextEditingController(text: 'Uganda');
  final _adminName = TextEditingController();
  final _adminEmail = TextEditingController();
  final _password = TextEditingController(text: generatePassword());
  String _currency = 'UGX';
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_church, _country, _adminName, _adminEmail, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final uid = ref.read(authStateProvider).value!.uid;
      await ref.read(platformRepositoryProvider).createChurchWithAdmin(
            platformUid: uid,
            churchName: _church.text.trim(),
            country: _country.text.trim(),
            currency: _currency,
            adminName: _adminName.text.trim(),
            adminEmail: _adminEmail.text.trim(),
            tempPassword: _password.text,
          );
      if (!mounted) return;
      await showCredentials(
        context,
        title: '${_church.text.trim()} is ready',
        email: _adminEmail.text.trim(),
        password: _password.text,
      );
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add church')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Church', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _church,
              decoration: const InputDecoration(labelText: 'Church name'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _country,
              decoration: const InputDecoration(labelText: 'Country'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: const InputDecoration(labelText: 'Currency'),
              items: const ['UGX', 'KES', 'TZS', 'RWF', 'GHS', 'NGN', 'ZAR', 'USD']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _currency = v ?? _currency),
            ),
            const SizedBox(height: 24),
            Text('Church administrator login', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _adminName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _adminEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (used to sign in)'),
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              decoration: InputDecoration(
                labelText: 'Temporary password',
                helperText: 'The administrator must change it at first sign-in',
                suffixIcon: IconButton(
                  tooltip: 'Generate new',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => setState(() => _password.text = generatePassword()),
                ),
              ),
              validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create church and login'),
            ),
          ],
        ),
      ),
    );
  }
}
