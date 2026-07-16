import 'package:blab/features/chat/state/typing_state.dart';
import 'package:blab/features/chats/widgets/chat_list_tile.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Chat _chat() {
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
}
