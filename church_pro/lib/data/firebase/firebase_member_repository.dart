import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/members/data/member_repository.dart';
import '../../features/members/domain/member.dart';
import 'firebase_helpers.dart';

/// churches/{churchId}/members/{memberId}
class FirebaseMemberRepository implements MemberRepository {
  FirebaseMemberRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String churchId) =>
      _db.collection('churches').doc(churchId).collection('members');

  @override
  Stream<List<Member>> watchMembers(String churchId) => _col(churchId).snapshots().map(
        (snap) => snap.docs.map((d) {
          final m = d.data();
          return Member(
            id: d.id,
            firstName: stringOf(m['firstName']),
            lastName: stringOf(m['lastName']),
            phone: stringOf(m['phone']),
            email: stringOf(m['email']),
            status: enumByName(MembershipStatus.values, m['status'], MembershipStatus.member),
            userUid: m['userUid'] as String?,
          );
        }).toList(),
      );

  @override
  Future<void> save(String churchId, Member member) {
    final isNew = member.id.isEmpty;
    final ref = isNew ? _col(churchId).doc() : _col(churchId).doc(member.id);
    return queued(ref.set({
      'firstName': member.firstName,
      'lastName': member.lastName,
      'phone': member.phone,
      'email': member.email,
      'status': member.status.name,
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)));
  }

  @override
  Future<void> delete(String churchId, String memberId) =>
      queued(_col(churchId).doc(memberId).delete());
}
