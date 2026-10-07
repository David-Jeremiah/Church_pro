import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../core/widgets/prompt_dialog.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  Future<void> _newService(BuildContext context, WidgetRef ref) async {
    final title = await promptText(context, title: 'New service', label: 'Title (e.g. Sunday Service)');
    if (title == null || title.isEmpty) return;
    await ref
        .read(attendanceRepositoryProvider)
        .createService(ref.read(activeChurchIdProvider)!, title: title, date: DateTime.now());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCreate = Permissions.can(ref.watch(currentRoleProvider), Permission.manageServices);
    final services = ref.watch(servicesProvider);

    return PermissionGate(
      permission: Permission.markAttendance,
      child: Scaffold(
        floatingActionButton: canCreate
            ? FloatingActionButton.extended(
                onPressed: () => _newService(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('New service'),
              )
            : null,
        body: services.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (list) => list.isEmpty
              ? const Center(child: Text('No services yet'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) => ListTile(
                    title: Text(list[i].title),
                    subtitle: Text(formatDate(list[i].date)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/attendance/service', extra: list[i]),
                  ),
                ),
        ),
      ),
    );
  }
}
