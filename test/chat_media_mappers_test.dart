import 'package:blab/shared/data/chat_mappers.dart';
import 'package:blab/shared/models/message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('image message row maps caption and attachment metadata', () {
    final row = {
      'id': 'msg-1',
      'chat_id': 'chat-1',
      'sender_id': 'me',
      'body': 'look at this',
      'message_type': 'image',
      'created_at': '2026-08-03T18:00:00Z',
      'edited_at': null,
      'reply_to': null,
      'deleted_at': null,
    };
    final attachment = {
      'id': 'att-1',
      'message_id': 'msg-1',
      'chat_id': 'chat-1',
      'storage_bucket': 'message-media',
      'storage_path': 'chat-1/me/msg-1.jpg',
      'mime_type': 'image/jpeg',
      'byte_size': 1200,
      'url': 'https://example.test/signed.jpg',
    };

    final message = messagesFromRows(
      [row],
      currentUserId: 'me',
      attachmentsByMessageId: {
        'msg-1': [attachment],
      },
    ).single;

    expect(message.type, MessageType.image);
    expect(message.originalText, 'look at this');
    expect(message.attachment?.storagePath, 'chat-1/me/msg-1.jpg');
    expect(message.attachment?.mimeType, 'image/jpeg');
    expect(message.attachment?.url, 'https://example.test/signed.jpg');
  });
}
