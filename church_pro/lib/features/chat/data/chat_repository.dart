import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/firebase/firebase_helpers.dart';
import '../domain/chat_models.dart';

/// churches/{c}/channels/{id}            a group, or a direct message between two people
/// churches/{c}/channels/{id}/messages   the messages
///
/// You only see channels you are a member of.
class ChatRepository {
  ChatRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _channels(String c) =>
      _db.collection('churches').doc(c).collection('channels');

  Map<String, String> _names(Object? raw) =>
      raw is Map ? {for (final e in raw.entries) '${e.key}': '${e.value}'} : <String, String>{};

  Stream<List<Channel>> watchChannels(String churchId, String uid) =>
      _channels(churchId).where('members', arrayContains: uid).snapshots().map(
            (s) => s.docs
                .map((d) {
                  final m = d.data();
                  return Channel(
                    id: d.id,
                    name: stringOf(m['name']),
                    isDm: m['kind'] == 'dm',
                    members: ((m['members'] as List?) ?? const []).whereType<String>().toList(),
                    memberNames: _names(m['memberNames']),
                    lastMessage: stringOf(m['lastMessage']),
                    lastAt: m['lastAt'] is Timestamp ? (m['lastAt'] as Timestamp).toDate() : null,
                    lastBy: stringOf(m['lastBy']),
                  );
                })
                .toList()
              ..sort((a, b) => (b.lastAt ?? DateTime(2000)).compareTo(a.lastAt ?? DateTime(2000))),
          );

  /// Newest first (the screen shows the list upside down so it starts at the bottom).
  Stream<List<ChatMessage>> watchMessages(String churchId, String channelId) => _channels(churchId)
      .doc(channelId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => ChatMessage(
                  id: d.id,
                  authorUid: stringOf(d.data()['authorUid']),
                  authorName: stringOf(d.data()['authorName']),
                  text: stringOf(d.data()['text']),
                  createdAt: dateFrom(d.data()['createdAt']),
                ))
            .toList(),
      );

  /// Opens the direct message with [otherUid], creating it the first time.
  Future<String> openDirect(
    String churchId, {
    required String myUid,
    required String myName,
    required String otherUid,
    required String otherName,
  }) async {
    final ids = [myUid, otherUid]..sort();
    final id = 'dm_${ids.join('_')}';
    // Only stable fields are written, so doing this again changes nothing.
    await _channels(churchId).doc(id).set({
      'kind': 'dm',
      'name': '',
      'members': ids,
      'memberNames': {myUid: myName, otherUid: otherName},
    }, SetOptions(merge: true));
    return id;
  }

  /// A group the admin sets up and chooses the members of.
  Future<String> createGroup(
    String churchId, {
    required String name,
    required String myUid,
    required Map<String, String> people,
  }) async {
    final ref = _channels(churchId).doc();
    await ref.set({
      'kind': 'group',
      'name': name,
      'members': people.keys.toList(),
      'memberNames': people,
      'createdBy': myUid,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastAt': FieldValue.serverTimestamp(),
      'lastBy': '',
    });
    return ref.id;
  }

  Future<void> updateMembers(String churchId, String channelId, Map<String, String> people) =>
      _channels(churchId).doc(channelId).update({'members': people.keys.toList(), 'memberNames': people});

  Future<void> send(
    String churchId,
    String channelId, {
    required String text,
    required String uid,
    required String name,
  }) {
    final channel = _channels(churchId).doc(channelId);
    final batch = _db.batch();
    batch.set(channel.collection('messages').doc(), {
      'authorUid': uid,
      'authorName': name,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(channel, {
      'lastMessage': text.length > 120 ? text.substring(0, 120) : text,
      'lastAt': FieldValue.serverTimestamp(),
      'lastBy': name,
    });
    return queued(batch.commit());
  }
}
