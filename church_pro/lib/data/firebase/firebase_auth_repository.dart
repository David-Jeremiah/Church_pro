import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/app_user.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  @override
  Stream<AppUser?> authStateChanges() => _auth.userChanges().map((u) {
        if (u == null) return null;
        final email = u.email ?? '';
        final name = (u.displayName ?? '').isNotEmpty ? u.displayName! : email.split('@').first;
        return AppUser(uid: u.uid, displayName: name, email: email);
      });

  @override
  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw Exception(authMessage(e));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(authMessage(e));
    }
  }

  @override
  Future<void> changePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('You are not signed in');
    try {
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code == 'requires-recent-login'
          ? 'Please sign out, sign in again, then change your password'
          : authMessage(e));
    }
    final ref = _db.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (doc.data()?['mustChangePassword'] == true) {
      await ref.update({'mustChangePassword': false});
    }
  }

  @override
  Stream<bool> watchIsPlatformAdmin(String uid) =>
      _db.collection('platformAdmins').doc(uid).snapshots().map((s) => s.exists);

  @override
  Stream<bool> watchMustChangePassword(String uid) =>
      _db.collection('users').doc(uid).snapshots().map((s) => s.data()?['mustChangePassword'] == true);
}

String authMessage(FirebaseAuthException e) => switch (e.code) {
      'invalid-credential' || 'wrong-password' || 'user-not-found' => 'Wrong email or password',
      'invalid-email' => 'That email address is not valid',
      'email-already-in-use' => 'An account with this email already exists',
      'weak-password' => 'Password must be at least 6 characters',
      'network-request-failed' => 'No internet connection',
      'too-many-requests' => 'Too many attempts. Try again later',
      'user-disabled' => 'This account has been disabled',
      _ => e.message ?? 'Authentication failed',
    };
