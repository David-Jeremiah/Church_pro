import '../domain/church_service.dart';

/// TODO(firebase): churches/{id}/services and services/{id}/attendance/{memberId}.
abstract class AttendanceRepository {
  Stream<List<ChurchService>> watchServices(String churchId);
  Future<void> createService(String churchId, {required String title, required DateTime date});
  Stream<Set<String>> watchPresent(String churchId, String serviceId);
  Future<void> setPresent(String churchId, String serviceId, String memberId, bool present);
}
