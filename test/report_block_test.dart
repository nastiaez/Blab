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

  Widget host(
    Message message, {
    DateTime? now,
    void Function(String emoji)? onReact,
  }) => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showMessageActionSheet(
            context,
            message: message,
            onAction: (_) {},
            onReact: onReact,
            now: now,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );

  Message msg({
    required bool outgoing,
    MessageStatus status = MessageStatus.delivered,
    DateTime? sentAt,
    String originalText = 'hello',
  }) => Message(
    id: 'm1',
    chatId: 'c1',
    isOutgoing: outgoing,
    originalText: originalText,
    translation: '',
    sentAt: sentAt ?? DateTime.parse('2026-06-09T00:00:00Z'),
    status: status,
  );

  testWidgets('action sheet shows Report on incoming messages', (tester) async {
    await tester.pumpWidget(host(msg(outgoing: false)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('View original'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.text('Edit'), findsNothing); // incoming: no edit
  });

  testWidgets('action sheet keeps the exact original text with mistakes', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(msg(outgoing: false, originalText: 'I goed to the shop yesterday.')),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('View original'), findsOneWidget);
    expect(find.text('I goed to the shop yesterday.'), findsOneWidget);
  });

  testWidgets('message action sheet content stays compact on wide screens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(msg(outgoing: false)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('original-message'))).width,
      lessThanOrEqualTo(392),
    );
  });

  testWidgets('action sheet offers free quick reactions and expanded emoji', (
    tester,
  ) async {
    final picked = <String>[];
    await tester.pumpWidget(host(msg(outgoing: false), onReact: picked.add));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('❤️'), findsOneWidget);
    expect(find.text('😂'), findsOneWidget);
    expect(find.text('👍'), findsOneWidget);
    expect(find.byKey(const ValueKey('more-reactions')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('more-reactions')));
    await tester.pumpAndSettle();
    expect(find.text('🔥'), findsOneWidget);

    await tester.tap(find.text('🔥'));
    await tester.pumpAndSettle();
    expect(picked, ['🔥']);
  });

  testWidgets('action sheet hides Report on your own messages', (tester) async {
    await tester.pumpWidget(host(msg(outgoing: true)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Report'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('Edit is shown only for recent delivered outgoing messages', (
    tester,
  ) async {
    final now = DateTime.parse('2026-07-17T12:00:00Z');
    await tester.pumpWidget(
      host(
        msg(outgoing: true, sentAt: now.subtract(const Duration(hours: 23))),
        now: now,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('Edit is hidden after 24 hours while Delete remains', (
    tester,
  ) async {
    final now = DateTime.parse('2026-07-17T12:00:00Z');
    await tester.pumpWidget(
      host(
        msg(outgoing: true, sentAt: now.subtract(const Duration(hours: 25))),
        now: now,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('pending messages cannot be replied to or edited', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(msg(outgoing: true, status: MessageStatus.pending)),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Reply'), findsNothing);
    expect(find.text('Edit'), findsNothing);
  });
}
