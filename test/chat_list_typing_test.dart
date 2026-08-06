import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:blab/features/chat/state/typing_state.dart';
import 'package:blab/features/chats/widgets/chat_list_tile.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Chat _chat({bool withLastMessageId = false, int unreadCount = 0}) {
  final german = kBlabLanguages.firstWhere((language) => language.code == 'de');
  final english = kBlabLanguages.firstWhere(
    (language) => language.code == 'en',
  );
  return Chat(
    id: 'chat-1',
    partnerName: 'Bob',
    partnerInitial: 'B',
    learningLanguage: german,
    partnerNativeLanguage: german,
    partnerLearningLanguage: english,
    lastMessage: 'Last message',
    lastMessageTranslation: '',
    lastMessageId: withLastMessageId ? 'message-1' : null,
    timestamp: DateTime(2026, 7, 16),
    unreadCount: unreadCount,
  );
}

Widget _app({required bool partnerTyping, Chat? chat}) {
  chat ??= _chat(withLastMessageId: true);
  return ProviderScope(
    overrides: [
      partnerTypingProvider(
        chat.id,
      ).overrideWith((ref) => Stream.value(partnerTyping)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ChatListTile(chat: chat, onTap: () {}),
      ),
    ),
  );
}

void main() {
  testWidgets('typing replaces the chat preview without an Online label', (
    tester,
  ) async {
    await tester.pumpWidget(_app(partnerTyping: true));
    await tester.pump();

    expect(find.text('typing...'), findsOneWidget);
    expect(find.text('Last message'), findsNothing);
    expect(find.text('Online'), findsNothing);
  });

  testWidgets('last message returns when partner is not typing', (
    tester,
  ) async {
    await tester.pumpWidget(_app(partnerTyping: false));
    await tester.pump();

    expect(find.text('typing...'), findsNothing);
    expect(find.text('Last message'), findsOneWidget);
  });

  testWidgets(
    'empty chat renders connection state without stale preview or unread badge',
    (tester) async {
      await tester.pumpWidget(
        _app(partnerTyping: false, chat: _chat(unreadCount: 3)),
      );
      await tester.pump();

      expect(find.text('New connection · say hi'), findsOneWidget);
      expect(find.text('Last message'), findsNothing);
      expect(find.text('3'), findsNothing);
    },
  );

  testWidgets('chat preview preserves authored text without AI requests', (
    tester,
  ) async {
    var calls = 0;
    final chat = _chat(withLastMessageId: true);
    final container = ProviderContainer(
      overrides: [
        translateMessageFnProvider.overrideWithValue((id) async {
          calls++;
          return MessageTranslation(
            translation: 'Letzte Nachricht',
            interfaceText: 'Last message',
            interfaceLang: 'en',
            sourceLang: 'en',
            tokens: const [],
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ChatListTile(chat: chat, onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Last message'), findsOneWidget);
    expect(calls, 0);
    expect(find.text('Letzte Nachricht'), findsNothing);
  });
}
