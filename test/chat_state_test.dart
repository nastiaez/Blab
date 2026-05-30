import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/shared/models/message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chatMessagesProvider', () {
    test('seeds the Aswin chat with mock messages', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final messages = container.read(chatMessagesProvider('aswin'));
      expect(messages, isNotEmpty);
      expect(messages.first.chatId, 'aswin');
    });

    test('returns empty list for unknown chats', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(chatMessagesProvider('maria')), isEmpty);
    });

    test('addOutgoing appends a delivered message then flips to read',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final before =
          container.read(chatMessagesProvider('maria')).length;
      container
          .read(chatMessagesProvider('maria').notifier)
          .addOutgoing('hi');

      final after = container.read(chatMessagesProvider('maria'));
      expect(after.length, before + 1);
      final newMsg = after.last;
      expect(newMsg.isOutgoing, true);
      expect(newMsg.originalText, 'hi');
      expect(newMsg.status, MessageStatus.delivered);

      // Wait for the 1500ms delivered→read transition.
      await Future<void>.delayed(const Duration(milliseconds: 1700));
      final updated = container.read(chatMessagesProvider('maria')).last;
      expect(updated.status, MessageStatus.read);
    });

    test('addOutgoing ignores empty / whitespace input', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final before = container.read(chatMessagesProvider('maria')).length;
      container
          .read(chatMessagesProvider('maria').notifier)
          .addOutgoing('   ');
      expect(
          container.read(chatMessagesProvider('maria')).length, before);
    });
  });

  group('showTranslationsProvider', () {
    test('defaults to true and toggles independently per chat', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(showTranslationsProvider('aswin')), true);
      expect(container.read(showTranslationsProvider('maria')), true);

      container.read(showTranslationsProvider('aswin').notifier).toggle();
      expect(container.read(showTranslationsProvider('aswin')), false);
      // Other chats unaffected.
      expect(container.read(showTranslationsProvider('maria')), true);
    });
  });
}
