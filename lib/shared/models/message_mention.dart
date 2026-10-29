/// A selected identity and its UTF-16 range in the authored message.
/// Text that merely looks like @name is never promoted to an identity.
class MessageMention {
  const MessageMention({
    required this.userId,
    required this.label,
    required this.start,
  });
  final String userId;
  final String label;
  final int start;
  String get text => '@$label';
  int get end => start + text.length;
  MessageMention at(int offset) =>
      MessageMention(userId: userId, label: label, start: offset);
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'label': label,
    'start': start,
  };

  static List<MessageMention> parse(Object? raw, String body) {
    if (raw is! List || raw.length > 50) return const [];
    final result = <MessageMention>[];
    var end = 0;
    for (final item in raw) {
      if (item is! Map ||
          item['userId'] is! String ||
          item['label'] is! String ||
          item['start'] is! int) {
        return const [];
      }
      final m = MessageMention(
        userId: item['userId'] as String,
        label: item['label'] as String,
        start: item['start'] as int,
      );
      if (m.userId.isEmpty ||
          m.label.isEmpty ||
          m.start < end ||
          m.end > body.length ||
          body.substring(m.start, m.end) != m.text) {
        return const [];
      }
      result.add(m);
      end = m.end;
    }
    return List.unmodifiable(result);
  }
}
