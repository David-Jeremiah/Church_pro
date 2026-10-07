import '../domain/member.dart';

/// TODO(firebase): churches/{churchId}/members with pagination + offline cache.
abstract class MemberRepository {
  Stream<List<Member>> watchMembers(String churchId);

  /// Creates when [member.id] is empty, otherwise updates.
  Future<void> save(String churchId, Member member);
  Future<void> delete(String churchId, String memberId);
}
