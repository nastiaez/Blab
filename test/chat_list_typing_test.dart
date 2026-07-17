import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:blab/features/chat/state/typing_state.dart';
import 'package:blab/features/chats/widgets/chat_list_tile.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Chat _chat({bool withLastMessageId = false}) {
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
    unreadCount: 0,
  );
}

Widget _app({required bool partnerTyping}) {
  final chat = _chat();
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

  testWidgets('translation toggle gates preview AI requests', (tester) async {
    var calls = 0;
    final chat = _chat(withLastMessageId: true);
    final container = ProviderContainer(
      overrides: [
        translateMessageFnProvider.overrideWithValue((
          id,
          text,
          source,
          target,
        ) async {
          calls++;
          return MessageTranslation(
            translation: 'Letzte Nachricht',
            englishText: text,
            sourceLang: 'en',
            tokens: const [],
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(showTranslationsProvider(chat.id).notifier).toggle();

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
    expect(calls, 0);
    expect(find.text('Last message'), findsOneWidget);

    container.read(showTranslationsProvider(chat.id).notifier).toggle();
    await tester.pump();
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Letzte Nachricht'), findsOneWidget);
  });
}
