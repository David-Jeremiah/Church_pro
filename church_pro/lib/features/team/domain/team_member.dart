import '../../../core/constants/roles.dart';

class TeamMember {
  const TeamMember({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
  });

  final String uid;
  final String name;
  final String email;
  final ChurchRole role;
  final bool active;
}
