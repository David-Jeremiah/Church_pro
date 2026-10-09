import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/firebase/firebase_church_repository.dart' show churchFromDoc;
import '../../../data/firebase/firebase_helpers.dart';
import '../../../data/firebase/firebase_provisioning.dart';
import '../../church/domain/church.dart';

/// A person who can manage the whole platform (listed in `platformAdmins`).
class PlatformAdmin {
  const PlatformAdmin({required this.uid, required this.name, required this.email});

  final String uid;
  final String name;
  final String email;
}

/// Used only by platform admins (system owners).
class PlatformRepository {
  PlatformRepository({FirebaseFirestore? db, Provisioning? provisioning})
      : _db = db ?? FirebaseFirestore.instance,
        _provisioning = provisioning ?? Provisioning();

  final FirebaseFirestore _db;
  final Provisioning _provisioning;

  Stream<List<Church>> watchChurches() => _db
      .collection('churches')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(churchFromDoc).toList());

  // ── Platform admins ───────────────────────────────────────────────────
  Stream<List<PlatformAdmin>> watchAdmins() => _db.collection('platformAdmins').snapshots().map(
        (s) => s.docs
        .map((d) => PlatformAdmin(
      uid: d.id,
      name: stringOf(d.data()['name']),
      email: stringOf(d.data()['email']),
    ))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name)),
  );

  /// Creates a login for another platform admin. They must change the
  /// temporary password at first sign-in.
  Future<void> addAdmin({
    required String byUid,
    required String name,
    required String email,
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
          'provisionedBy': byUid,
        });
        batch.set(_db.collection('platformAdmins').doc(uid), {
          'name': name,
          'email': email,
          'createdAt': now,
          'addedBy': byUid,
        });
        await batch.commit(); // needs a connection
      },
    );
  }

  /// Removes platform-admin rights. The login itself stays, but it can no
  /// longer manage churches.
  Future<void> removeAdmin(String uid) => _db.collection('platformAdmins').doc(uid).delete();

  // ── Churches ──────────────────────────────────────────────────────────
  /// Creates the church, its administrator's login, and links them together.
  Future<void> createChurchWithAdmin({
    required String platformUid,
    required String churchName,
    required String country,
    required String currency,
    required String adminName,
    required String adminEmail,
    required String tempPassword,
  }) {
    return _provisioning.createUser<void>(
      email: adminEmail,
      password: tempPassword,
      name: adminName,
      onCreated: (adminUid) async {
        final churchRef = _db.collection('churches').doc();
        final now = FieldValue.serverTimestamp();
        final batch = _db.batch();
        batch.set(churchRef, {
          'name': churchName,
          'country': country,
          'currency': currency,
          'status': 'active',
          'createdBy': platformUid,
          'createdAt': now,
          'adminUid': adminUid,
          'adminEmail': adminEmail,
          'settings': {'blockOverBudget': true},
        });
        batch.set(_db.collection('users').doc(adminUid), {
          'displayName': adminName,
          'email': adminEmail,
          'createdAt': now,
          'mustChangePassword': true,
          'provisionedBy': platformUid,
        });
        batch.set(_db.collection('users').doc(adminUid).collection('memberships').doc(churchRef.id), {
          'churchName': churchName,
          'role': 'admin',
          'status': 'active',
          'joinedAt': now,
        });
        batch.set(churchRef.collection('team').doc(adminUid), {
          'displayName': adminName,
          'email': adminEmail,
          'role': 'admin',
          'status': 'active',
          'createdAt': now,
        });
        await batch.commit(); // needs a connection
      },
    );
  }

  Future<void> setChurchStatus(String churchId, String status) =>
      _db.collection('churches').doc(churchId).update({'status': status});
}