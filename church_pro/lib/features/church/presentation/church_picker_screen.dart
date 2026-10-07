import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';

class ChurchPickerScreen extends ConsumerWidget {
  const ChurchPickerScreen({super.key});

  void _open(BuildContext context, WidgetRef ref, String churchId) {
    ref.read(activeChurchIdProvider.notifier).set(churchId);
    context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberships = ref.watch(membershipsProvider);

    // Only one church: go straight in.
    ref.listen(membershipsProvider, (_, next) {
      final list = next.value;
      if (list != null && list.length == 1 && ref.read(activeChurchIdProvider) == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) _open(context, ref, list.first.churchId);
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a church'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(activeChurchIdProvider.notifier).set(null);
              ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
      body: memberships.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Your login is not linked to a church yet.\nPlease contact your church administrator.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (list.length == 1 && ref.read(activeChurchIdProvider) == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) _open(context, ref, list.first.churchId);
            });
          }
          return ListView(
            children: [
              for (final m in list)
                ListTile(
                  leading: CircleAvatar(child: Text(m.churchName.isEmpty ? '?' : m.churchName[0])),
                  title: Text(m.churchName),
                  subtitle: Text(m.role.label),
                  onTap: () => _open(context, ref, m.churchId),
                ),
            ],
          );
        },
      ),
    );
  }
}
