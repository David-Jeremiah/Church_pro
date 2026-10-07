import '../domain/church.dart';
import '../domain/membership.dart';

/// Implemented by data/firebase/firebase_church_repository.dart.
abstract class ChurchRepository {
  Stream<List<Membership>> watchMemberships(String uid);
  Stream<Church?> watchChurch(String churchId);
}
