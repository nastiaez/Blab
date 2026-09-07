import '../models/message.dart';

Message messageFromRow(
  Map<String, dynamic> row, {
  required String currentUserId,
  Map<String, Map<String, dynamic>> messageRowsById = const {},
  Map<String, List<Map<String, dynamic>>> attachmentsByMessageId = const {},
}) {
  final senderId = row['sender_id'] as String;
  final replyId = row['reply_to'] as String?;
  final replyRow = replyId == null ? null : messageRowsById[replyId];
  final attachmentRows =
      attachmentsByMessageId[row['id'] as String] ?? const [];
  final type = switch (row['message_type'] as String? ?? 'text') {
    'image' => MessageType.image,
    _ => MessageType.text,
  };
  return Message(
    id: row['id'] as String,
    chatId: row['chat_id'] as String,
    isOutgoing: senderId == currentUserId,
    originalText: row['body'] as String,
    translation: '',
    sentAt: DateTime.parse(row['created_at'] as String).toLocal(),
    status: MessageStatus.delivered,
    type: type,
    attachment: attachmentRows.isEmpty
        ? null
        : _attachmentFromRow(attachmentRows.first),
    isEdited: row['edited_at'] != null,
    replyTo: replyRow == null
        ? null
        : _replyPreviewFromRow(
            replyRow,
            currentUserId: currentUserId,
            attachmentsByMessageId: attachmentsByMessageId,
          ),
  );
}

List<Message> messagesFromRows(
  Iterable<Map<String, dynamic>> rows, {
  required String currentUserId,
  Iterable<Map<String, dynamic>> additionalReplyRows = const [],
  Map<String, List<Map<String, dynamic>>> attachmentsByMessageId = const {},
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
          attachmentsByMessageId: attachmentsByMessageId,
        ),
      )
      .toList();
}

Message _replyPreviewFromRow(
  Map<String, dynamic> row, {
  required String currentUserId,
  Map<String, List<Map<String, dynamic>>> attachmentsByMessageId = const {},
}) {
  final deleted = row['deleted_at'] != null;
  final attachmentRows =
      attachmentsByMessageId[row['id'] as String] ?? const [];
  final type = switch (row['message_type'] as String? ?? 'text') {
    'image' => MessageType.image,
    _ => MessageType.text,
  };
  return Message(
    id: row['id'] as String,
    chatId: row['chat_id'] as String,
    isOutgoing: row['sender_id'] == currentUserId,
    originalText: deleted ? 'Deleted message' : row['body'] as String,
    translation: '',
    sentAt: DateTime.parse(row['created_at'] as String).toLocal(),
    status: MessageStatus.delivered,
    type: deleted ? MessageType.text : type,
    attachment: deleted || attachmentRows.isEmpty
        ? null
        : _attachmentFromRow(attachmentRows.first),
    isEdited: row['edited_at'] != null,
  );
}

MessageAttachment _attachmentFromRow(Map<String, dynamic> row) {
  return MessageAttachment(
    id: row['id'] as String,
    messageId: row['message_id'] as String,
    chatId: row['chat_id'] as String,
    storageBucket: row['storage_bucket'] as String,
    storagePath: row['storage_path'] as String,
    mimeType: row['mime_type'] as String,
    byteSize: row['byte_size'] as int,
    previewStoragePath: row['preview_storage_path'] as String?,
    previewMimeType: row['preview_mime_type'] as String?,
    previewByteSize: (row['preview_byte_size'] as num?)?.toInt(),
    url: row['url'] as String?,
    localBytes: row['localBytes'] is List
        ? List<int>.from(row['localBytes'] as List)
        : null,
    previewUrl: row['preview_url'] as String?,
    previewBytes: row['previewBytes'] is List
        ? List<int>.from(row['previewBytes'] as List)
        : null,
  );
}
