import 'package:blab/features/chats/chats_screen.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blab/features/chat/widgets/report_sheet.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/state/chat_list_state.dart';

BlabLanguage _lang(String code) =>
    kBlabLanguages.firstWhere((l) => l.code == code);

Chat _chat(String id, String partnerId) => Chat(
  id: id,
  partnerId: partnerId,
  partnerName: 'P$id',
  partnerInitial: 'P',
  learningLanguage: _lang('ta'),
  mode: ChatMode.practice,
  partnerNativeLanguage: _lang('ta'),
  partnerLearningLanguage: _lang('uk'),
  lastMessage: 'hi',
  lastMessageTranslation: '',
  timestamp: DateTime.parse('2026-06-09T00:00:00Z'),
  unreadCount: 0,
);

class _FixedChatList extends ChatListNotifier {
  _FixedChatList(this.chats);

  final List<Chat> chats;

  @override
  Future<List<Chat>> build() async => chats;
}

void main() {
  test('share targets exclude chats whose partner is blocked', () {
    final chats = [_chat('a', 'u1'), _chat('b', 'u2')];
    expect(filterShareableChats(chats, {'u2'}).map((c) => c.id), ['a']);
  });

  test('share targets include all chats when nobody is blocked', () {
    final chats = [_chat('a', 'u1'), _chat('b', 'u2')];
    expect(filterShareableChats(chats, const {}).map((c) => c.id), ['a', 'b']);
  });

  test('share targets keep mock chats that have no partner id', () {
    final mock = Chat(
      id: 'm',
      partnerName: 'M',
      partnerInitial: 'M',
      learningLanguage: _lang('ta'),
      mode: ChatMode.practice,
      partnerNativeLanguage: _lang('ta'),
      partnerLearningLanguage: _lang('uk'),
      lastMessage: '',
      lastMessageTranslation: '',
      timestamp: DateTime.parse('2026-06-09T00:00:00Z'),
      unreadCount: 0,
    );
    expect(filterShareableChats([mock], {'x'}).map((c) => c.id), ['m']);
  });

  testWidgets('blocked conversations remain visible in Chats', (tester) async {
    final chats = [_chat('a', 'u1'), _chat('b', 'u2')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatListProvider.overrideWith(() => _FixedChatList(chats)),
          blockedUserIdsProvider.overrideWith((_) => Stream.value({'u2'})),
        ],
        child: const MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: ChatsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pa'), findsOneWidget);
    expect(find.text('Pb'), findsOneWidget);
  });

  test('report reasons map to stable wire values', () {
    expect(ReportReason.childSafety.wire, 'child_safety');
    expect(ReportReason.harassment.wire, 'harassment');
    // Every reason has a non-empty wire + label.
    for (final r in ReportReason.values) {
      expect(r.wire, isNotEmpty);
      expect(r.label, isNotEmpty);
    }
  });
}
