import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_auth_repository.dart' show authMessage;

/// Creates login accounts for other people without signing the current user out.
///
/// `createUserWithEmailAndPassword` normally signs in as the new user, so we do
/// it on a secondary Firebase app instance instead. If saving the user's
/// Firestore records fails, the new auth account is deleted again.
class Provisioning {
  Future<FirebaseAuth> _secondaryAuth() async {
    final existing = Firebase.apps.where((a) => a.name == 'provisioning').firstOrNull;
    final app = existing ??
        await Firebase.initializeApp(name: 'provisioning', options: Firebase.app().options);
    return FirebaseAuth.instanceFor(app: app);
  }

  Future<T> createUser<T>({
    required String email,
    required String password,
    required String name,
    required Future<T> Function(String uid) onCreated,
  }) async {
    final auth = await _secondaryAuth();
    final UserCredential cred;
    try {
      cred = await auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw Exception(authMessage(e));
    }
    final user = cred.user!;
    try {
      await user.updateDisplayName(name);
      return await onCreated(user.uid);
    } catch (_) {
      try {
        await user.delete();
      } catch (_) {}
      rethrow;
    } finally {
      await auth.signOut();
    }
  }
}
