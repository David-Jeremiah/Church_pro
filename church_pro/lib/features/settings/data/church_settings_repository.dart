import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/firebase/firebase_helpers.dart';

/// The church's own details: contact information and a small logo.
/// The logo is kept inside the document (resized to about 256 pixels) so no
/// extra file storage is needed.
class ChurchProfile {
  const ChurchProfile({this.phone = '', this.email = '', this.address = '', this.motto = '', this.logo});

  final String phone;
  final String email;
  final String address;
  final String motto;
  final Uint8List? logo;
}

/// churches/{c}/settings/profile   phone, email, address, motto, logo
/// churches/{c}/settings/access    modules: { people: [roles], planning: [...], ... }
class ChurchSettingsRepository {
  ChurchSettingsRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _church(String c) => _db.collection('churches').doc(c);
  DocumentReference<Map<String, dynamic>> _settings(String c, String name) => _church(c).collection('settings').doc(name);

  Stream<ChurchProfile> watchProfile(String churchId) => _settings(churchId, 'profile').snapshots().map((d) {
    final m = d.data() ?? const <String, dynamic>{};
    final logo = m['logo'];
    return ChurchProfile(
      phone: stringOf(m['phone']),
      email: stringOf(m['email']),
      address: stringOf(m['address']),
      motto: stringOf(m['motto']),
      logo: logo is Blob ? logo.bytes : null,
    );
  });

  Future<void> saveProfile(
      String churchId, {
        required String phone,
        required String email,
        required String address,
        required String motto,
        Uint8List? newLogo,
        bool removeLogo = false,
      }) =>
      queued(_settings(churchId, 'profile').set({
        'phone': phone,
        'email': email,
        'address': address,
        'motto': motto,
        if (newLogo != null) 'logo': Blob(newLogo),
        if (newLogo == null && removeLogo) 'logo': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)));

  Stream<Map<String, List<String>>> watchAccess(String churchId) => _settings(churchId, 'access').snapshots().map((d) {
    final raw = d.data()?['modules'];
    if (raw is! Map) return <String, List<String>>{};
    return {
      for (final e in raw.entries)
        '${e.key}': ((e.value as List?) ?? const []).whereType<String>().toList(),
    };
  });

  Future<void> saveAccess(String churchId, Map<String, List<String>> modules) =>
      queued(_settings(churchId, 'access').set({
        'modules': modules,
        'updatedAt': FieldValue.serverTimestamp(),
      }));

  Future<void> resetAccess(String churchId) => queued(_settings(churchId, 'access').delete());

  Future<void> setBlockOverBudget(String churchId, bool value) =>
      queued(_church(churchId).update({'settings.blockOverBudget': value}));
}