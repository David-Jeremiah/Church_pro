import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/planning_models.dart';

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Timestamp _startOfToday() {
  final n = DateTime.now();
  return Timestamp.fromDate(DateTime(n.year, n.month, n.day));
}

/// Firestore layout (all under churches/{churchId}):
///   plannedServices/{yyyy-MM-dd}_{n}   one doc per service on a Sunday
///   calendarItems/{auto id}            meetings, events, holidays
///   settings/servicePattern            { slots: [{name, time}, ...] }
class PlanningRepository {
  PlanningRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _church(String id) => _db.collection('churches').doc(id);
  CollectionReference<Map<String, dynamic>> _services(String id) => _church(id).collection('plannedServices');
  CollectionReference<Map<String, dynamic>> _items(String id) => _church(id).collection('calendarItems');
  DocumentReference<Map<String, dynamic>> _pattern(String id) =>
      _church(id).collection('settings').doc('servicePattern');

  // ── Planned services ───────────────────────────────────────────────────
  /// Services from today onward.
  Stream<List<PlannedService>> watchPlanned(String churchId) {
    return _services(churchId)
        .where('date', isGreaterThanOrEqualTo: _startOfToday())
        .orderBy('date')
        .limit(60)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => PlannedService.fromMap(d.id, d.data())).toList();
      list.sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.order.compareTo(b.order);
      });
      return list;
    });
  }

  /// Replaces whatever was planned for [date] with [services].
  Future<void> savePlan(String churchId, DateTime date, List<PlannedService> services) {
    final key = _key(date);
    final batch = _db.batch();
    for (var i = 0; i < services.length; i++) {
      final s = services[i];
      batch.set(
        _services(churchId).doc('${key}_$i'),
        PlannedService(
          date: date,
          name: s.name,
          time: s.time,
          preacher: s.preacher,
          leader: s.leader,
          isJoint: s.isJoint,
          order: i,
        ).toMap(),
      );
    }
    // Remove leftovers, e.g. three services replaced by one joint service.
    for (var i = services.length; i < 8; i++) {
      batch.delete(_services(churchId).doc('${key}_$i'));
    }
    return batch.commit();
  }

  // ── Calendar items ─────────────────────────────────────────────────────
  Stream<List<CalendarItem>> watchItems(String churchId) {
    return _items(churchId)
        .where('date', isGreaterThanOrEqualTo: _startOfToday())
        .orderBy('date')
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map((d) => CalendarItem.fromMap(d.id, d.data())).toList());
  }

  Future<void> saveItem(String churchId, CalendarItem item) {
    if (item.id.isEmpty) return _items(churchId).add(item.toMap());
    return _items(churchId).doc(item.id).set(item.toMap());
  }

  Future<void> deleteItem(String churchId, String itemId) => _items(churchId).doc(itemId).delete();

  // ── Service pattern ────────────────────────────────────────────────────
  Stream<List<ServiceSlot>> watchPattern(String churchId) => _pattern(churchId).snapshots().map((s) {
        final raw = s.data()?['slots'];
        if (raw is! List || raw.isEmpty) return ServiceSlot.defaults;
        return [for (final m in raw) ServiceSlot.fromMap(Map<String, dynamic>.from(m as Map))];
      });

  Future<void> savePattern(String churchId, List<ServiceSlot> slots) =>
      _pattern(churchId).set({'slots': [for (final s in slots) s.toMap()]});
}
