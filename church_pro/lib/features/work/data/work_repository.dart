import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/firebase/firebase_helpers.dart';
import '../domain/work_log.dart';

/// churches/{c}/workLogs/{uid_yyyy-MM-dd}  one record per person per day:
/// where they worked (office / home / field), when, and what they did.
class WorkRepository {
  WorkRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String c) =>
      _db.collection('churches').doc(c).collection('workLogs');

  WorkLog _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return WorkLog(
      id: d.id,
      uid: stringOf(m['uid']),
      userName: stringOf(m['userName']),
      date: stringOf(m['date']),
      mode: enumByName(WorkMode.values, m['mode'], WorkMode.office),
      clockIn: dateFrom(m['clockIn']),
      clockOut: m['clockOut'] is Timestamp ? (m['clockOut'] as Timestamp).toDate() : null,
      notes: stringOf(m['notes']),
    );
  }

  Stream<List<WorkLog>> watchMyLogs(String churchId, String uid) =>
      _col(churchId).where('uid', isEqualTo: uid).snapshots().map(
            (s) => s.docs.map(_fromDoc).toList()..sort((a, b) => b.date.compareTo(a.date)),
          );

  /// Everyone's logs for the last [days] days (admin team view).
  Stream<List<WorkLog>> watchTeamLogs(String churchId, {int days = 31}) {
    final since = dayKey(DateTime.now().subtract(Duration(days: days)));
    return _col(churchId)
        .where('date', isGreaterThanOrEqualTo: since)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  Future<void> clockIn(String churchId, {required String uid, required String name, required WorkMode mode}) {
    final now = DateTime.now();
    return queued(_col(churchId).doc('${uid}_${dayKey(now)}').set({
      'uid': uid,
      'userName': name,
      'date': dayKey(now),
      'mode': mode.name,
      'clockIn': Timestamp.fromDate(now),
      'clockOut': null,
      'notes': '',
    }));
  }

  Future<void> clockOut(String churchId, WorkLog log, String notes) => queued(_col(churchId).doc(log.id).update({
        'clockOut': Timestamp.fromDate(DateTime.now()),
        'notes': notes,
      }));

  /// Record a day that was forgotten (shown as a manual entry).
  Future<void> logPastDay(
    String churchId, {
    required String uid,
    required String name,
    required DateTime day,
    required WorkMode mode,
    required double hours,
    required String notes,
  }) {
    final start = DateTime(day.year, day.month, day.day, 8);
    return queued(_col(churchId).doc('${uid}_${dayKey(day)}').set({
      'uid': uid,
      'userName': name,
      'date': dayKey(day),
      'mode': mode.name,
      'clockIn': Timestamp.fromDate(start),
      'clockOut': Timestamp.fromDate(start.add(Duration(minutes: (hours * 60).round()))),
      'notes': notes,
    }));
  }
}
