enum MembershipStatus { visitor, newConvert, member, inactive }

class Member {
  const Member({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phone = '',
    this.email = '',
    this.status = MembershipStatus.member,
    this.userUid,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final MembershipStatus status;

  /// Set once this member links to a signed-in app user.
  final String? userUid;

  String get fullName => '$firstName $lastName'.trim();

  Member copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    MembershipStatus? status,
  }) =>
      Member(
        id: id ?? this.id,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        status: status ?? this.status,
        userUid: userUid,
      );
}
