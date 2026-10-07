import '../../../core/constants/roles.dart';

/// A user's membership in one church (mirrors users/{uid}/memberships/{churchId}).
class Membership {
  const Membership({
    required this.churchId,
    required this.churchName,
    required this.role,
  });

  final String churchId;
  final String churchName;
  final ChurchRole role;
}
