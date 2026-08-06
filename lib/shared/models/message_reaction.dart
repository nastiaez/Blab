class MessageReactionRow {
  const MessageReactionRow({
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;
}

class MessageReactionSummary {
  const MessageReactionSummary({
    required this.emoji,
    required this.count,
    required this.reactedByMe,
  });

  final String emoji;
  final int count;
  final bool reactedByMe;
}

enum MessageReactionChangeType { upsert, remove, resync }

class MessageReactionChange {
  const MessageReactionChange._(this.type, this.row);

  const MessageReactionChange.upsert(Map<String, dynamic> row)
    : this._(MessageReactionChangeType.upsert, row);

  const MessageReactionChange.remove(Map<String, dynamic> row)
    : this._(MessageReactionChangeType.remove, row);

  const MessageReactionChange.resync()
    : this._(MessageReactionChangeType.resync, null);

  final MessageReactionChangeType type;
  final Map<String, dynamic>? row;
}

MessageReactionRow? messageReactionRowFromMap(Map<String, dynamic> row) {
  final messageId = row['message_id'];
  final userId = row['user_id'];
  final emoji = row['emoji'];
  final createdAt = row['created_at'];
  if (messageId is! String ||
      userId is! String ||
      emoji is! String ||
      createdAt is! String) {
    return null;
  }
  return MessageReactionRow(
    messageId: messageId,
    userId: userId,
    emoji: emoji,
    createdAt: DateTime.parse(createdAt).toLocal(),
  );
}

Map<String, List<MessageReactionSummary>> aggregateMessageReactions(
  Iterable<MessageReactionRow> rows, {
  required String currentUserId,
}) {
  final byMessage =
      <String, Map<String, ({int count, bool mine, DateTime at})>>{};
  for (final row in rows) {
    final message = byMessage.putIfAbsent(row.messageId, () => {});
    final existing = message[row.emoji];
    message[row.emoji] = (
      count: (existing?.count ?? 0) + 1,
      mine: (existing?.mine ?? false) || row.userId == currentUserId,
      at: existing == null || row.createdAt.isBefore(existing.at)
          ? row.createdAt
          : existing.at,
    );
  }
  return {
    for (final entry in byMessage.entries)
      entry.key:
          entry.value.entries
              .map(
                (emoji) => MessageReactionSummary(
                  emoji: emoji.key,
                  count: emoji.value.count,
                  reactedByMe: emoji.value.mine,
                ),
              )
              .toList()
            ..sort((a, b) {
              final aData = entry.value[a.emoji]!;
              final bData = entry.value[b.emoji]!;
              if (aData.mine != bData.mine) return aData.mine ? -1 : 1;
              if (aData.count != bData.count) return bData.count - aData.count;
              return aData.at.compareTo(bData.at);
            }),
  };
}
