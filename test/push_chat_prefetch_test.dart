import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/services/local_chat_history_cache.dart';
import 'package:blab/shared/services/push_chat_prefetch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Service implements ChatService {
  bool failPackages = false;
  int? limit;
  int packageCalls = 0;
  @override
  Future<List<Message>> fetchMessages(String chatId, {int limit = 50}) async {
    this.limit = limit;
    return [
      Message(
        id: 'm1',
        chatId: chatId,
        isOutgoing: false,
        originalText: 'New message',
        translation: '',
        sentAt: DateTime.utc(2026),
        status: MessageStatus.delivered,
      ),
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPreparedPackages({
    required String chatId,
    required List<String> messageIds,
  }) async {
    packageCalls++;
    if (failPackages) throw StateError('not available');
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'received originals are cached without waiting for language help',
    () async {
      final s = _Service()..failPackages = true;
      await expectLater(
        prefetchPushedChat(
          chatId: 'chat-1',
          service: s,
          cache: LocalChatHistoryCache('alice'),
          accountStillCurrent: () => true,
        ),
        throwsStateError,
      );
      expect(
        (await LocalChatHistoryCache(
          'alice',
        ).loadMessages('chat-1')).single.originalText,
        'New message',
      );
      expect(
        await LocalChatHistoryCache('bob').loadMessages('chat-1'),
        isEmpty,
      );
      expect(s.limit, 50);
    },
  );
  test('account switch prevents late push work from writing cache', () async {
    final s = _Service();
    await prefetchPushedChat(
      chatId: 'chat-1',
      service: s,
      cache: LocalChatHistoryCache('alice'),
      accountStillCurrent: () => false,
    );
    expect(
      await LocalChatHistoryCache('alice').loadMessages('chat-1'),
      isEmpty,
    );
    expect(s.packageCalls, 0);
  });
}
