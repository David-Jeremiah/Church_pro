import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/planning/data/planning_repository.dart';
import '../features/planning/domain/planning_models.dart';
import 'providers.dart';

final planningRepositoryProvider = Provider<PlanningRepository>((ref) => PlanningRepository());

/// Every planned service from today onward, ordered by date then by slot.
final plannedServicesProvider = StreamProvider<List<PlannedService>>((ref) {
  final churchId = ref.watch(activeChurchIdProvider);
  if (churchId == null) return Stream.value(const <PlannedService>[]);
  return ref.watch(planningRepositoryProvider).watchPlanned(churchId);
});

/// Upcoming meetings, events and holidays.
final calendarItemsProvider = StreamProvider<List<CalendarItem>>((ref) {
  final churchId = ref.watch(activeChurchIdProvider);
  if (churchId == null) return Stream.value(const <CalendarItem>[]);
  return ref.watch(planningRepositoryProvider).watchItems(churchId);
});

/// The church's usual Sunday services (names and times).
final servicePatternProvider = StreamProvider<List<ServiceSlot>>((ref) {
  final churchId = ref.watch(activeChurchIdProvider);
  if (churchId == null) return Stream.value(ServiceSlot.defaults);
  return ref.watch(planningRepositoryProvider).watchPattern(churchId);
});