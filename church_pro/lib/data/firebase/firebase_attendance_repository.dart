import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/attendance/data/attendance_repository.dart';
import '../../features/attendance/domain/church_service.dart';
import 'firebase_helpers.dart';

/// churches/{churchId}/services/{serviceId}
/// churches/{churchId}/services/{serviceId}/attendance/{memberId}  (exists = present)
class FirebaseAttendanceRepository implements AttendanceRepository {
  FirebaseAttendanceRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _services(String churchId) =>
      _db.collection('churches').doc(churchId).collection('services');

  @override
  Stream<List<ChurchService>> watchServices(String churchId) =>
      _services(churchId).orderBy('date', descending: true).snapshots().map(
            (snap) => snap.docs
                .map((d) => ChurchService(
                      id: d.id,
                      title: stringOf(d.data()['title']),
                      date: dateFrom(d.data()['date']),
                    ))
                .toList(),
          );

  @override
  Future<void> createService(String churchId, {required String title, required DateTime date}) =>
      queued(_services(churchId).doc().set({
        'title': title,
        'date': Timestamp.fromDate(date),
        'createdAt': FieldValue.serverTimestamp(),
      }));

  @override
  Stream<Set<String>> watchPresent(String churchId, String serviceId) => _services(churchId)
      .doc(serviceId)
      .collection('attendance')
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.id).toSet());

  @override
  Future<void> setPresent(String churchId, String serviceId, String memberId, bool present) {
    final ref = _services(churchId).doc(serviceId).collection('attendance').doc(memberId);
    if (!present) return queued(ref.delete());
    return queued(ref.set({
      'markedBy': FirebaseAuth.instance.currentUser?.uid,
      'markedAt': FieldValue.serverTimestamp(),
    }));
  }
}
