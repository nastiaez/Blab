import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blab/features/chat/widgets/message_action_sheet.dart';
import 'package:blab/features/chat/widgets/report_sheet.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/state/chat_list_state.dart';

BlabLanguage _lang(String code) =>
    kBlabLanguages.firstWhere((l) => l.code == code);

Chat _chat(String id, String partnerId) => Chat(
      id: id,
      partnerId: partnerId,
      partnerName: 'P$id',
      partnerInitial: 'P',
      learningLanguage: _lang('ta'),
      partnerNativeLanguage: _lang('ta'),
      partnerLearningLanguage: _lang('uk'),
      lastMessage: 'hi',
      lastMessageTranslation: '',
      timestamp: DateTime.parse('2026-06-09T00:00:00Z'),
      unreadCount: 0,
    );

void main() {
  test('filterBlockedChats hides chats whose partner is blocked', () {
    final chats = [_chat('a', 'u1'), _chat('b', 'u2')];
    expect(filterBlockedChats(chats, {'u2'}).map((c) => c.id), ['a']);
  });

  test('filterBlockedChats with an empty set shows all chats', () {
    final chats = [_chat('a', 'u1'), _chat('b', 'u2')];
    expect(filterBlockedChats(chats, const {}).map((c) => c.id), ['a', 'b']);
  });

  test('filterBlockedChats keeps chats that have no partner id', () {
    final mock = Chat(
      id: 'm',
      partnerName: 'M',
      partnerInitial: 'M',
      learningLanguage: _lang('ta'),
      partnerNativeLanguage: _lang('ta'),
      partnerLearningLanguage: _lang('uk'),
      lastMessage: '',
      lastMessageTranslation: '',
      timestamp: DateTime.parse('2026-06-09T00:00:00Z'),
      unreadCount: 0,
    );
    expect(filterBlockedChats([mock], {'x'}).map((c) => c.id), ['m']);
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

  Widget host(Message message) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showMessageActionSheet(
                context,
                message: message,
                onAction: (_) {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

  Message msg({required bool outgoing}) => Message(
        id: 'm1',
        chatId: 'c1',
        isOutgoing: outgoing,
        originalText: 'hello',
        translation: '',
        sentAt: DateTime.parse('2026-06-09T00:00:00Z'),
        status: MessageStatus.delivered,
      );

  testWidgets('action sheet shows Report on incoming messages',
      (tester) async {
    await tester.pumpWidget(host(msg(outgoing: false)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Edit'), findsNothing); // incoming: no edit
  });

  testWidgets('action sheet hides Report on your own messages',
      (tester) async {
    await tester.pumpWidget(host(msg(outgoing: true)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Report'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);
  });
}
