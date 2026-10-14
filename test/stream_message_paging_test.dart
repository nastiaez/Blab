import 'package:blab/shared/services/stream_message_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat/stream_chat.dart' as stream;

void main() {
  final at = DateTime.utc(2026, 10, 14);
  stream.Message row(String id, int seconds) => stream.Message(
    id: id,
    text: id,
    user: stream.User(id: 'alice'),
    createdAt: at.add(Duration(seconds: seconds)),
  );
  test(
    'bounded page keeps newest rows and returns the oldest retained cursor',
    () {
      final result = pageFromStream(
        [row('older', 0), row('newest', 2), row('middle', 1)],
        chatId: 'chat',
        userId: 'alice',
        limit: 2,
      );
      expect(result.messages.map((m) => m.id), ['middle', 'newest']);
      expect(result.hasMore, true);
      expect(result.nextCursor!.id, 'middle');
    },
  );
  test(
    'deleted last row still advances paging without exposing a tombstone bubble',
    () {
      final result = pageFromStream(
        [row('deleted', 0).copyWith(deletedAt: at), row('visible', 1)],
        chatId: 'chat',
        userId: 'alice',
        limit: 2,
      );
      expect(result.messages.map((m) => m.id), ['visible']);
      expect(result.nextCursor!.id, 'deleted');
      expect(result.hasMore, false);
    },
  );
  test('same-timestamp rows use deterministic identity ordering', () {
    final result = pageFromStream(
      [row('b', 0), row('a', 0)],
      chatId: 'chat',
      userId: 'alice',
      limit: 2,
    );
    expect(result.messages.map((m) => m.id), ['a', 'b']);
  });
}
