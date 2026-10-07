import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore writes only complete once the server confirms. While offline they
/// would wait forever, so we let the UI continue after a short wait. The write
/// stays in the local cache and syncs when the connection returns. Server
/// rejections that arrive within the wait (e.g. permission-denied) still throw.
Future<void> queued(Future<void> write) =>
    write.timeout(const Duration(seconds: 3), onTimeout: () {});

T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

DateTime dateFrom(Object? value) => value is Timestamp ? value.toDate() : DateTime.now();

String stringOf(Object? value) => value is String ? value : '';
