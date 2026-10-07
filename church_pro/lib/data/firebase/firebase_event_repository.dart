import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/events/data/event_repository.dart';
import '../../features/events/domain/church_event.dart';
import 'firebase_helpers.dart';

/// churches/{churchId}/events/{eventId}
class FirebaseEventRepository implements EventRepository {
  FirebaseEventRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String churchId) =>
      _db.collection('churches').doc(churchId).collection('events');

  @override
  Stream<List<ChurchEvent>> watchEvents(String churchId) =>
      _col(churchId).orderBy('start').snapshots().map(
            (snap) => snap.docs
                .map((d) => ChurchEvent(
                      id: d.id,
                      title: stringOf(d.data()['title']),
                      start: dateFrom(d.data()['start']),
                      location: stringOf(d.data()['location']),
                    ))
                .toList(),
          );

  @override
  Future<void> addEvent(String churchId, ChurchEvent event) => queued(_col(churchId).doc().set({
        'title': event.title,
        'start': Timestamp.fromDate(event.start),
        'location': event.location,
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      }));
}
