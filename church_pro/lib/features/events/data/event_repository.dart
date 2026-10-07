import '../domain/church_event.dart';

/// TODO(firebase): churches/{id}/events (+ FCM topic notifications).
abstract class EventRepository {
  Stream<List<ChurchEvent>> watchEvents(String churchId);
  Future<void> addEvent(String churchId, ChurchEvent event);
}
