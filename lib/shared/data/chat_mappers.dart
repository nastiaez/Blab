import '../models/message.dart';

Message messageFromRow(Map<String, dynamic> row, {required String currentUserId}) {
  final senderId = row['sender_id'] as String;
  return Message(
    id: row['id'] as String,
    chatId: row['chat_id'] as String,
    isOutgoing: senderId == currentUserId,
    originalText: row['body'] as String,
    translation: '',
    sentAt: DateTime.parse(row['created_at'] as String).toLocal(),
    status: MessageStatus.delivered,
    isEdited: row['edited_at'] != null,
  );
}
