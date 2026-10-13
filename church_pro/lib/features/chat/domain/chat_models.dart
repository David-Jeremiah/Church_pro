class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.isDm,
    required this.members,
    required this.memberNames,
    this.lastMessage = '',
    this.lastAt,
    this.lastBy = '',
  });

  final String id;

  /// The name of a group. A direct message is named after the other person.
  final String name;
  final bool isDm;
  final List<String> members;
  final Map<String, String> memberNames;
  final String lastMessage;
  final DateTime? lastAt;
  final String lastBy;

  String titleFor(String myUid) {
    if (!isDm) return name.isEmpty ? 'Group' : name;
    for (final e in memberNames.entries) {
      if (e.key != myUid) return e.value;
    }
    return 'Direct message';
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String text;
  final DateTime createdAt;
}