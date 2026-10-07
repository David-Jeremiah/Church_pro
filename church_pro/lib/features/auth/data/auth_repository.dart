import '../domain/app_user.dart';

/// Accounts are created by a platform admin or a church admin, so there is no
/// self-registration. Implemented by data/firebase/firebase_auth_repository.dart.
abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  Future<void> signInWithEmail(String email, String password);
  Future<void> signOut();
  Future<void> sendPasswordReset(String email);
  Future<void> changePassword(String newPassword);

  /// True when the user is listed in `platformAdmins` (the system owner).
  Stream<bool> watchIsPlatformAdmin(String uid);

  /// True until a newly created login has set its own password.
  Stream<bool> watchMustChangePassword(String uid);
}
