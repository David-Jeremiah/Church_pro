import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/roles.dart';
import '../../features/church/data/church_repository.dart';
import '../../features/church/domain/church.dart';
import '../../features/church/domain/membership.dart';
import 'firebase_helpers.dart';

/// users/{uid}/memberships/{churchId} -> churchName, role, status, joinedAt
/// churches/{churchId}                -> name, country, currency, status, adminEmail, settings
class FirebaseChurchRepository implements ChurchRepository {
  FirebaseChurchRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Stream<List<Membership>> watchMemberships(String uid) =>
      _db.collection('users').doc(uid).collection('memberships').snapshots().map(
            (snap) => snap.docs
                .where((d) => (d.data()['status'] ?? 'active') == 'active')
                .map((d) => Membership(
                      churchId: d.id,
                      churchName: stringOf(d.data()['churchName']),
                      role: ChurchRole.fromName(d.data()['role'] as String?),
                    ))
                .toList(),
          );

  @override
  Stream<Church?> watchChurch(String churchId) =>
      _db.collection('churches').doc(churchId).snapshots().map((s) => s.exists ? churchFromDoc(s) : null);
}

Church churchFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
  final m = d.data() ?? const {};
  final settings = (m['settings'] as Map?)?.cast<String, dynamic>() ?? const {};
  return Church(
    id: d.id,
    name: stringOf(m['name']),
    currency: m['currency'] is String ? m['currency'] as String : 'UGX',
    status: m['status'] is String ? m['status'] as String : 'active',
    country: stringOf(m['country']),
    adminEmail: stringOf(m['adminEmail']),
    blockOverBudget: settings['blockOverBudget'] != false,
    createdAt: m['createdAt'] is Timestamp ? (m['createdAt'] as Timestamp).toDate() : null,
  );
}
