import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;

import '../../../app/providers.dart';
import '../../../core/widgets/church_logo.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../planning/presentation/service_pattern_sheet.dart';

/// The church admin's own settings: logo and contact details, who sees what,
/// service times, and the over-budget rule.
class ChurchSettingsScreen extends ConsumerStatefulWidget {
  const ChurchSettingsScreen({super.key});

  @override
  ConsumerState<ChurchSettingsScreen> createState() => _ChurchSettingsScreenState();
}

class _ChurchSettingsScreenState extends ConsumerState<ChurchSettingsScreen> {
  final _motto = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  Uint8List? _newLogo;
  bool _removeLogo = false;
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_motto, _phone, _email, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  void _say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickLogo() async {
    final picked = await FilePicker.pickFiles(type: FileType.image);
    if (picked.isEmpty) return;
    final file = picked.first;
    final bytes = await picked.first.xFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      _say('That file is not a picture the app can read. Try a PNG or JPG.');
      return;
    }
    final square = img.copyResizeCropSquare(decoded, size: 256);
    var out = img.encodePng(square);
    if (out.length > 200000) out = img.encodeJpg(square, quality: 80);
    setState(() {
      _newLogo = out;
      _removeLogo = false;
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(settingsRepositoryProvider).saveProfile(
        ref.read(activeChurchIdProvider)!,
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        address: _address.text.trim(),
        motto: _motto.text.trim(),
        newLogo: _newLogo,
        removeLogo: _removeLogo,
      );
      if (mounted) {
        setState(() {
          _newLogo = null;
          _removeLogo = false;
        });
        _say('Saved');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(churchProfileProvider);
    final church = ref.watch(churchProvider).value;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);

    if (!_loaded && profile.hasValue) {
      final p = profile.value!;
      _motto.text = p.motto;
      _phone.text = p.phone;
      _email.text = p.email;
      _address.text = p.address;
      _loaded = true;
    }

    final currentLogo = _removeLogo ? null : (_newLogo ?? profile.value?.logo);

    return Scaffold(
      appBar: AppBar(title: const Text('Church settings')),
      body: ContentWidth(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            const SectionTitle('Logo and details'),
            Row(
              children: [
                if (currentLogo != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.memory(currentLogo, width: 88, height: 88, fit: BoxFit.cover),
                  )
                else
                  const ChurchLogo(size: 88),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _pickLogo,
                        icon: const Icon(Icons.image_outlined),
                        label: Text(currentLogo == null ? 'Choose a logo' : 'Change logo'),
                      ),
                      if (currentLogo != null)
                        TextButton(
                          onPressed: () => setState(() {
                            _newLogo = null;
                            _removeLogo = true;
                          }),
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('A square picture works best. It is shown across the app.', style: TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(controller: _motto, decoration: const InputDecoration(labelText: 'Motto or tagline (optional)')),
            const SizedBox(height: 12),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 12),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : const Text('Save'),
            ),
            const SectionTitle('Who can see what'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Choose which roles see each part of the app'),
                subtitle: const Text('People, planning, inventory, messages, reports, team work board'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/access'),
              ),
            ),
            const SectionTitle('Services and budgets'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Service names and times'),
                    subtitle: const Text('For example 1st service 7:00 AM, 2nd 9:30 AM, 3rd 12:00 PM'),
                    onTap: () => showServicePatternSheet(context),
                  ),
                  const Divider(),
                  SwitchListTile(
                    secondary: const Icon(Icons.block),
                    title: const Text('Block purchase requests over budget'),
                    subtitle: const Text('When on, a request cannot be sent or approved if the budget line cannot cover it'),
                    value: church?.blockOverBudget ?? true,
                    onChanged: (v) =>
                        ref.read(settingsRepositoryProvider).setBlockOverBudget(ref.read(activeChurchIdProvider)!, v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}