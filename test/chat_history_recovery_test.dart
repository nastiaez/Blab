import 'dart:async';

import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/services/local_chat_history_cache.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StalledHistoryService implements ChatService {
  @override
  Future<MessagePage> fetchMessagePage(
    String chatId, {
    int limit = 50,
    MessageCursor? before,
  }) => Completer<MessagePage>().future;

  @override
  Stream<MessageChange> watchMessageChanges(String chatId) =>
      const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'cached messages render before a stalled history request completes',
    () async {
      final cache = LocalChatHistoryCache('alice');
      await cache.saveMessages('chat-1', [
        Message(
          id: 'message-1',
          chatId: 'chat-1',
          isOutgoing: false,
          originalText: 'Cached message',
          translation: '',
          sentAt: DateTime.utc(2026, 8, 29, 12),
          status: MessageStatus.delivered,
        ),
      ]);
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('alice'),
          chatServiceProvider.overrideWithValue(_StalledHistoryService()),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        chatMessagesProvider('chat-1'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final deadline = DateTime.now().add(const Duration(milliseconds: 500));
      while (container.read(chatMessagesProvider('chat-1')).value == null &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final messages = container.read(chatMessagesProvider('chat-1')).value!;

      expect(messages.single.originalText, 'Cached message');
    },
  );
}
