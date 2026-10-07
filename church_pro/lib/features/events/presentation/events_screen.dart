import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/prompt_dialog.dart';
import '../domain/church_event.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final title = await promptText(context, title: 'New event', label: 'Title');
    if (title == null || title.isEmpty || !context.mounted) return;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (date == null) return;
    await ref
        .read(eventRepositoryProvider)
        .addEvent(ref.read(activeChurchIdProvider)!, ChurchEvent(id: '', title: title, start: date));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = Permissions.can(ref.watch(currentRoleProvider), Permission.manageEvents);
    final events = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _add(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('New event'),
            )
          : null,
      body: events.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('No upcoming events'));
          final sorted = [...list]..sort((a, b) => a.start.compareTo(b.start));
          return ListView(
            children: [
              for (final e in sorted)
                ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(e.title),
                  subtitle: Text(formatDate(e.start)),
                ),
            ],
          );
        },
      ),
    );
  }
}
