import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_chip.dart';
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
            ? 'Nobody in this church will be able to use the app until you activate it again.'
            : 'The church will be able to use the app again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(suspend ? 'Suspend' : 'Activate')),
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
        title: const Text('Platform admin · Churches'),
        actions: [
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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/platform/add'),
        icon: const Icon(Icons.add_business),
        label: const Text('Add church'),
      ),
      body: churches.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No churches yet. Tap "Add church" to onboard the first one.'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = list[i];
              return ListTile(
                leading: CircleAvatar(child: Text(c.name.isEmpty ? '?' : c.name[0])),
                title: Text(c.name),
                subtitle: Text([
                  c.adminEmail,
                  if (c.country.isNotEmpty) c.country,
                  c.currency,
                  if (c.createdAt != null) 'since ${formatDate(c.createdAt!)}',
                ].join(' · ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusChip(c.isActive ? 'Active' : 'Suspended', color: c.isActive ? Colors.green : Colors.red),
                    PopupMenuButton<String>(
                      onSelected: (v) => v == 'toggle' ? _toggle(context, ref, c) : _resetAdmin(context, ref, c),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'toggle', child: Text(c.isActive ? 'Suspend church' : 'Activate church')),
                        const PopupMenuItem(value: 'reset', child: Text('Send password reset to admin')),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
