import 'dart:math';

/// Temporary password for a newly created login (no look-alike characters).
String generatePassword({int length = 10}) {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
  final random = Random.secure();
  return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
}
