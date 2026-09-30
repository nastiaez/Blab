import 'package:blab/app/theme.dart';
import 'package:blab/features/chats/chats_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedChatList extends ChatListNotifier {
  _FixedChatList(this.chats);

  final List<Chat> chats;

  @override
  Future<List<Chat>> build() async => chats;
}

Chat _chat() {
  final english = kBlabLanguages.firstWhere(
    (language) => language.code == 'en',
  );
  final german = kBlabLanguages.firstWhere((language) => language.code == 'de');
  return Chat(
    id: 'chat-1',
    partnerName: 'Alex',
    partnerInitial: 'A',
    learningLanguage: german,
    mode: ChatMode.practice,
    partnerNativeLanguage: german,
    partnerLearningLanguage: english,
    lastMessage: 'Hallo',
    lastMessageTranslation: 'Hello',
    timestamp: DateTime(2026, 9, 23),
    unreadCount: 0,
  );
}

Future<void> _pumpChats(WidgetTester tester, List<Chat> chats) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatListProvider.overrideWith(() => _FixedChatList(chats)),
        onlineProvider.overrideWith((_) => Stream.value(true)),
      ],
      child: MaterialApp(
        theme: blabTheme,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const ChatsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'empty Chats explains the value without a duplicate plus action',
    (tester) async {
      await _pumpChats(tester, const <Chat>[]);

      expect(find.text('Start your first chat'), findsOneWidget);
      expect(
        find.text('Practice a language through real conversations.'),
        findsOneWidget,
      );
      expect(find.text('Invite a friend'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    },
  );

  testWidgets('Chats keeps the new-chat action once a conversation exists', (
    tester,
  ) async {
    await _pumpChats(tester, [_chat()]);

    expect(find.text('Alex'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    final actionRect = tester.getRect(find.byType(FloatingActionButton));
    expect(actionRect.width, greaterThanOrEqualTo(48));
    expect(actionRect.height, greaterThanOrEqualTo(48));
  });
}
