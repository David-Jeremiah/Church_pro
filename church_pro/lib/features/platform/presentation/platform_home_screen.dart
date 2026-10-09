import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../church/domain/church.dart';

/// Console for the platform admin (system owner): add churches, give them
/// logins, suspend or re-activate them.
class PlatformHomeScreen extends ConsumerWidget {
  const PlatformHomeScreen({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, Church c) async {
    final suspend = c.isActive;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(suspend ? 'Suspend ${c.name}?' : 'Activate ${c.name}?'),
        content: Text(suspend
            ? 'Nobody in this church can use the app until you activate it again. Their data is kept.'
            : 'The church can use the app again straight away.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(suspend ? 'Suspend church' : 'Activate church')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(platformRepositoryProvider).setChurchStatus(c.id, suspend ? 'suspended' : 'active');
    }
  }

  Future<void> _resetAdmin(BuildContext context, WidgetRef ref, Church c) async {
    await ref.read(authRepositoryProvider).sendPasswordReset(c.adminEmail);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reset link sent to ${c.adminEmail}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final churches = ref.watch(platformChurchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform console'),
        actions: [
          IconButton(
            tooltip: 'Platform admins',
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () => context.push('/platform/admins'),
          ),
          IconButton(
            tooltip: 'Change password',
            icon: const Icon(Icons.lock_reset),
            onPressed: () => context.push('/change-password'),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: churches.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          final active = list.where((c) => c.isActive).length;
          final title = list.isEmpty
              ? 'No churches yet'
              : (list.length == 1 ? '1 church' : '${list.length} churches');
          final subtitle = list.isEmpty
              ? 'Add the first church to create its administrator login.'
              : (active == list.length ? 'All of them are active.' : '$active active, ${list.length - active} suspended.');

          return ContentWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                HeroBanner(
                  title: title,
                  subtitle: subtitle,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.ink),
                      onPressed: () => context.push('/platform/add'),
                      icon: const Icon(Icons.add_business),
                      label: const Text('Add a church'),
                    ),
                  ),
                ),
                if (list.isNotEmpty) ...[
                  const SectionTitle('Churches'),
                  _ChurchTable(
                    churches: list,
                    onToggle: (c) => _toggle(context, ref, c),
                    onReset: (c) => _resetAdmin(context, ref, c),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChurchTable extends StatelessWidget {
  const _ChurchTable({required this.churches, required this.onToggle, required this.onReset});

  final List<Church> churches;
  final void Function(Church) onToggle;
  final void Function(Church) onReset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < churches.length; i++) ...[
            if (i > 0) const Divider(),
            Builder(builder: (context) {
              final c = churches[i];
              final place = [if (c.country.isNotEmpty) c.country, c.currency].join(', ');
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  children: [
                    InitialAvatar(c.name, size: 46),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(c.adminEmail, style: TextStyle(color: muted, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            c.createdAt == null ? place : '$place. Added ${formatDate(c.createdAt!)}.',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(c.isActive ? 'Active' : 'Suspended', color: c.isActive ? AppColors.success : AppColors.danger),
                    PopupMenuButton<String>(
                      onSelected: (v) => v == 'toggle' ? onToggle(c) : onReset(c),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'toggle', child: Text(c.isActive ? 'Suspend church' : 'Activate church')),
                        const PopupMenuItem(value: 'reset', child: Text('Send password reset to admin')),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}