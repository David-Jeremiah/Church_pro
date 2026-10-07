import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/roles.dart';
import '../../../data/firebase/firebase_helpers.dart';
import '../../../data/firebase/firebase_provisioning.dart';
import '../domain/team_member.dart';

/// churches/{churchId}/team/{uid}  (mirror of each login in this church)
class TeamRepository {
  TeamRepository({FirebaseFirestore? db, Provisioning? provisioning})
      : _db = db ?? FirebaseFirestore.instance,
        _provisioning = provisioning ?? Provisioning();

  final FirebaseFirestore _db;
  final Provisioning _provisioning;

  Stream<List<TeamMember>> watchTeam(String churchId) =>
      _db.collection('churches').doc(churchId).collection('team').snapshots().map(
            (s) => s.docs
                .map((d) => TeamMember(
                      uid: d.id,
                      name: stringOf(d.data()['displayName']),
                      email: stringOf(d.data()['email']),
                      role: ChurchRole.fromName(d.data()['role'] as String?),
                      active: (d.data()['status'] ?? 'active') == 'active',
                    ))
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
          );

  /// Creates a login for a new team member (called by the church admin).
  Future<void> createLogin({
    required String adminUid,
    required String churchId,
    required String churchName,
    required String name,
    required String email,
    required ChurchRole role,
    required String tempPassword,
  }) {
    return _provisioning.createUser<void>(
      email: email,
      password: tempPassword,
      name: name,
      onCreated: (uid) async {
        final now = FieldValue.serverTimestamp();
        final batch = _db.batch();
        batch.set(_db.collection('users').doc(uid), {
          'displayName': name,
          'email': email,
          'createdAt': now,
          'mustChangePassword': true,
          'provisionedBy': adminUid,
          'provisionedChurchId': churchId,
        });
        batch.set(_db.collection('users').doc(uid).collection('memberships').doc(churchId), {
          'churchName': churchName,
          'role': role.name,
          'status': 'active',
          'joinedAt': now,
        });
        batch.set(_db.collection('churches').doc(churchId).collection('team').doc(uid), {
          'displayName': name,
          'email': email,
          'role': role.name,
          'status': 'active',
          'createdAt': now,
        });
        await batch.commit();
      },
    );
  }

  Future<void> setRole(String churchId, String uid, ChurchRole role) => _update(churchId, uid, {'role': role.name});

  Future<void> setActive(String churchId, String uid, bool active) =>
      _update(churchId, uid, {'status': active ? 'active' : 'suspended'});

  Future<void> _update(String churchId, String uid, Map<String, Object?> fields) {
    final batch = _db.batch();
    batch.update(_db.collection('churches').doc(churchId).collection('team').doc(uid), fields);
    batch.update(_db.collection('users').doc(uid).collection('memberships').doc(churchId), fields);
    return queued(batch.commit());
  }
}
