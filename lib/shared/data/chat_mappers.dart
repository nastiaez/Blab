import '../models/message.dart';

Message messageFromRow(
  Map<String, dynamic> row, {
  required String currentUserId,
  Map<String, Map<String, dynamic>> messageRowsById = const {},
}) {
  final senderId = row['sender_id'] as String;
  final replyId = row['reply_to'] as String?;
  final replyRow = replyId == null ? null : messageRowsById[replyId];
  return Message(
    id: row['id'] as String,
    chatId: row['chat_id'] as String,
    isOutgoing: senderId == currentUserId,
    originalText: row['body'] as String,
    translation: '',
    sentAt: DateTime.parse(row['created_at'] as String).toLocal(),
    status: MessageStatus.delivered,
    isEdited: row['edited_at'] != null,
    replyTo: replyRow == null
        ? null
        : _replyPreviewFromRow(replyRow, currentUserId: currentUserId),
  );
}

List<Message> messagesFromRows(
  Iterable<Map<String, dynamic>> rows, {
  required String currentUserId,
  Iterable<Map<String, dynamic>> additionalReplyRows = const [],
}) {
  final sourceRows = rows.toList();
  final byId = <String, Map<String, dynamic>>{
    for (final row in additionalReplyRows) row['id'] as String: row,
    for (final row in sourceRows) row['id'] as String: row,
  };
  return sourceRows
      .where((row) => row['deleted_at'] == null)
      .map(
        (row) => messageFromRow(
          row,
          currentUserId: currentUserId,
          messageRowsById: byId,
        ),
      )
      .toList();
}

Message _replyPreviewFromRow(
  Map<String, dynamic> row, {
  required String currentUserId,
}) {
  final deleted = row['deleted_at'] != null;
  return Message(
    id: row['id'] as String,
    chatId: row['chat_id'] as String,
    isOutgoing: row['sender_id'] == currentUserId,
    originalText: deleted ? 'Deleted message' : row['body'] as String,
    translation: '',
    sentAt: DateTime.parse(row['created_at'] as String).toLocal(),
    status: MessageStatus.delivered,
    isEdited: row['edited_at'] != null,
  );
}
