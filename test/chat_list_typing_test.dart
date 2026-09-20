import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:blab/features/chat/state/typing_state.dart';
import 'package:blab/features/chats/widgets/chat_list_tile.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Chat _chat({
  bool withLastMessageId = false,
  int unreadCount = 0,
  DateTime? timestamp,
}) {
  final german = kBlabLanguages.firstWhere((language) => language.code == 'de');
  final english = kBlabLanguages.firstWhere(
    (language) => language.code == 'en',
  );
  return Chat(
    id: 'chat-1',
    partnerName: 'Bob',
    partnerInitial: 'B',
    learningLanguage: german,
    mode: ChatMode.practice,
    partnerNativeLanguage: german,
    partnerLearningLanguage: english,
    lastMessage: 'Last message',
    lastMessageTranslation: '',
    lastMessageId: withLastMessageId ? 'message-1' : null,
    timestamp: timestamp ?? DateTime(2026, 7, 16),
    unreadCount: unreadCount,
  );
}

Widget _app({
  required bool partnerTyping,
  Chat? chat,
  Locale locale = const Locale('en'),
}) {
  chat ??= _chat(withLastMessageId: true);
  return ProviderScope(
    overrides: [
      partnerTypingProvider(
        chat.id,
      ).overrideWith((ref) => Stream.value(partnerTyping)),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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

  testWidgets('connection preview and relative time follow the app locale', (
    tester,
  ) async {
    final chat = _chat(
      withLastMessageId: true,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    );
    await tester.pumpWidget(
      _app(partnerTyping: false, chat: chat, locale: const Locale('uk')),
    );
    await tester.pump();

    expect(find.text('1 дн'), findsOneWidget);

    await tester.pumpWidget(
      _app(partnerTyping: false, chat: _chat(), locale: const Locale('uk')),
    );
    await tester.pump();
    expect(find.text('Новий контакт · привітайся'), findsOneWidget);
  });

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
