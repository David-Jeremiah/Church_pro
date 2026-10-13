import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/planning_providers.dart';
import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../attendance/domain/church_service.dart';
import '../domain/planning_models.dart';

/// The planner tab: coming Sundays, dates to remember, and recent attendance.
class PlanningScreen extends ConsumerWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool can(Permission p) => ref.watch(canProvider(p));

    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);
    final now = DateTime.now();

    final planned = ref.watch(plannedServicesProvider).value ?? const <PlannedService>[];
    final items = ref.watch(calendarItemsProvider).value ?? const <CalendarItem>[];
    final services = ref.watch(servicesProvider).value ?? const <ChurchService>[];

    final canManage = can(Permission.manageServices);
    final first = sundayOnOrAfter(now);
    final sundays = [for (var i = 0; i < 5; i++) DateTime(first.year, first.month, first.day + 7 * i)];

    final children = <Widget>[];

    // ── Coming Sundays ───────────────────────────────────────────────────
    if (can(Permission.viewPlanning)) {
      children.add(const SectionTitle('Coming Sundays'));
      for (final d in sundays) {
        final plan = planned.where((s) => sameDay(s.date, d)).toList();
        final String text;
        final Color color;
        final IconData icon;
        if (plan.isEmpty) {
          text = 'Not planned yet';
          color = AppColors.warning;
          icon = Icons.event_busy_outlined;
        } else {
          final noPreacher = plan.where((s) => !s.hasPreacher).length;
          final noLeader = plan.where((s) => !s.hasLeader).length;
          final kind = plan.first.isJoint ? 'Joint service' : '${plan.length} services';
          if (noPreacher == 0 && noLeader == 0) {
            text = '$kind, everyone assigned';
            color = AppColors.success;
            icon = Icons.event_available;
          } else {
            text = '$kind: ${[
              if (noPreacher > 0) '$noPreacher without a preacher',
              if (noLeader > 0) '$noLeader without a leader',
            ].join(', ')}';
            color = AppColors.warning;
            icon = Icons.record_voice_over_outlined;
          }
        }
        children.add(Card(
          child: ListTile(
            leading: Icon(icon, color: color),
            title: Text(sameDay(d, now) ? 'Today, ${formatDate(d)}' : formatDate(d),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(text, style: TextStyle(color: muted, fontSize: 12)),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () => context.push('/attendance/sunday?date=${dayKey(d)}'),
          ),
        ));
      }
    }

    // ── Dates to remember ────────────────────────────────────────────────
    if (can(Permission.viewPlanning)) {
      children.add(const SectionTitle('Dates to remember'));
      if (items.isEmpty) {
        children.add(const EmptyState(
          icon: Icons.event_outlined,
          title: 'Nothing coming up',
          message: 'Meetings, events and holidays you add will show here.',
        ));
      } else {
        for (final item in items) {
          children.add(Card(
            child: ListTile(
              leading: Icon(item.kind.icon, color: scheme.primary),
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                [formatDate(item.date), if (item.time.isNotEmpty) item.time].join(',  '),
                style: TextStyle(color: muted, fontSize: 12),
              ),
              trailing: canManage ? Icon(Icons.chevron_right, color: muted) : null,
              onTap: canManage ? () => context.push('/attendance/item', extra: item) : null,
            ),
          ));
        }
      }
      if (canManage) {
        children
          ..add(const SizedBox(height: 8))
          ..add(Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => context.push('/attendance/item'),
              icon: const Icon(Icons.add),
              label: const Text('Add a date'),
            ),
          ));
      }
    }

    // ── Attendance ───────────────────────────────────────────────────────
    if (can(Permission.markAttendance)) {
      children.add(const SectionTitle('Attendance'));
      if (services.isEmpty) {
        children.add(const EmptyState(
          icon: Icons.fact_check_outlined,
          title: 'No services yet',
          message: 'Services you record attendance for will appear here.',
        ));
      } else {
        for (final s in services.take(8)) {
          children.add(Card(
            child: ListTile(
              leading: Icon(Icons.church_outlined, color: scheme.primary),
              title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: Consumer(
                builder: (context, ref, _) {
                  final n = ref.watch(presentIdsProvider(s.id)).value?.length ?? 0;
                  return Text('$n present', style: Theme.of(context).textTheme.titleSmall);
                },
              ),
              onTap: () => context.push('/attendance/service', extra: s),
            ),
          ));
        }
      }
    }

    if (children.isEmpty) {
      children.add(const EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'Nothing here yet',
        message: 'You do not have access to planning in this church.',
      ));
    }

    return ContentWidth(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: children),
    );
  }
}