import 'package:flutter_test/flutter_test.dart';
import 'package:blab/shared/data/chat_mappers.dart';

void main() {
  test('message row to model preserves all fields', () {
    final row = {
      'id': 'msg-1',
      'chat_id': 'chat-1',
      'sender_id': 'user-1',
      'body': 'hello',
      'created_at': '2026-05-30T12:00:00Z',
      'edited_at': null,
      'reply_to': null,
      'deleted_at': null,
    };
    final m = messageFromRow(row, currentUserId: 'user-1');
    expect(m.id, 'msg-1');
    expect(m.chatId, 'chat-1');
    expect(m.isOutgoing, true);
    expect(m.originalText, 'hello');
    expect(m.isEdited, false);
  });

  test('incoming when sender != current user', () {
    final m = messageFromRow({
      'id': 'msg-2', 'chat_id': 'c', 'sender_id': 'them',
      'body': 'hi', 'created_at': '2026-05-30T12:00:00Z',
      'edited_at': null, 'reply_to': null, 'deleted_at': null,
    }, currentUserId: 'me');
    expect(m.isOutgoing, false);
  });

  test('edited flag set when edited_at present', () {
    final m = messageFromRow({
      'id': 'a', 'chat_id': 'c', 'sender_id': 'me', 'body': 'x',
      'created_at': '2026-05-30T12:00:00Z',
      'edited_at': '2026-05-30T12:01:00Z',
      'reply_to': null, 'deleted_at': null,
    }, currentUserId: 'me');
    expect(m.isEdited, true);
  });
}
