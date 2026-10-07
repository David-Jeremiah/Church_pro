import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/church_service.dart';

class ServiceAttendanceScreen extends ConsumerWidget {
  const ServiceAttendanceScreen({super.key, required this.service});

  final ChurchService service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final churchId = ref.watch(activeChurchIdProvider)!;
    final members = ref.watch(membersProvider);
    final present = ref.watch(presentIdsProvider(service.id)).value ?? <String>{};

    return Scaffold(
      appBar: AppBar(title: Text(service.title)),
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('${present.length} / ${list.length} present',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final m in list)
                    CheckboxListTile(
                      value: present.contains(m.id),
                      title: Text(m.fullName),
                      onChanged: (v) => ref
                          .read(attendanceRepositoryProvider)
                          .setPresent(churchId, service.id, m.id, v ?? false),
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
