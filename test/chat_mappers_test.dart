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
      'languages_matched_at_send': true,
    };
    final m = messageFromRow(row, currentUserId: 'user-1');
    expect(m.id, 'msg-1');
    expect(m.chatId, 'chat-1');
    expect(m.isOutgoing, true);
    expect(m.originalText, 'hello');
    expect(m.isEdited, false);
    expect(m.languagesMatchedAtSend, true);
    expect(m.copyWith(status: m.status).languagesMatchedAtSend, true);
  });

  test('legacy message rows fail closed when match eligibility is absent', () {
    final m = messageFromRow({
      'id': 'legacy',
      'chat_id': 'c',
      'sender_id': 'them',
      'body': 'old message',
      'created_at': '2026-05-30T12:00:00Z',
      'edited_at': null,
      'reply_to': null,
      'deleted_at': null,
    }, currentUserId: 'me');

    expect(m.languagesMatchedAtSend, false);
  });

  test('incoming when sender != current user', () {
    final m = messageFromRow({
      'id': 'msg-2',
      'chat_id': 'c',
      'sender_id': 'them',
      'body': 'hi',
      'created_at': '2026-05-30T12:00:00Z',
      'edited_at': null,
      'reply_to': null,
      'deleted_at': null,
    }, currentUserId: 'me');
    expect(m.isOutgoing, false);
  });

  test('edited flag set when edited_at present', () {
    final m = messageFromRow({
      'id': 'a',
      'chat_id': 'c',
      'sender_id': 'me',
      'body': 'x',
      'created_at': '2026-05-30T12:00:00Z',
      'edited_at': '2026-05-30T12:01:00Z',
      'reply_to': null,
      'deleted_at': null,
    }, currentUserId: 'me');
    expect(m.isEdited, true);
  });

  test('message rows resolve persisted replies', () {
    final rows = <Map<String, dynamic>>[
      {
        'id': 'source',
        'chat_id': 'c',
        'sender_id': 'them',
        'body': 'original',
        'created_at': '2026-05-30T12:00:00Z',
        'edited_at': null,
        'reply_to': null,
        'deleted_at': null,
        'languages_matched_at_send': true,
      },
      {
        'id': 'reply',
        'chat_id': 'c',
        'sender_id': 'me',
        'body': 'response',
        'created_at': '2026-05-30T12:01:00Z',
        'edited_at': null,
        'reply_to': 'source',
        'deleted_at': null,
      },
    ];

    final messages = messagesFromRows(rows, currentUserId: 'me');

    expect(messages.last.replyTo?.id, 'source');
    expect(messages.last.replyTo?.originalText, 'original');
    expect(messages.last.replyTo?.isOutgoing, false);
    expect(messages.last.replyTo?.languagesMatchedAtSend, true);
  });

  test('deleted reply targets use a non-sensitive placeholder', () {
    final target = <String, dynamic>{
      'id': 'source',
      'chat_id': 'c',
      'sender_id': 'me',
      'body': 'private deleted text',
      'created_at': '2026-05-30T12:00:00Z',
      'edited_at': null,
      'reply_to': null,
      'deleted_at': '2026-05-30T12:02:00Z',
    };
    final reply = <String, dynamic>{
      'id': 'reply',
      'chat_id': 'c',
      'sender_id': 'them',
      'body': 'response',
      'created_at': '2026-05-30T12:01:00Z',
      'edited_at': null,
      'reply_to': 'source',
      'deleted_at': null,
    };

    final messages = messagesFromRows(
      [reply],
      currentUserId: 'me',
      additionalReplyRows: [target],
    );

    expect(messages.single.replyTo?.originalText, 'Deleted message');
    expect(messages.single.replyTo?.originalText, isNot(contains('private')));
  });
}
