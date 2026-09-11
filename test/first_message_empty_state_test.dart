import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blab/features/chat/widgets/first_message_empty_state.dart';
import 'package:blab/features/invite/widgets/exchange_card.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/models/chat.dart';

BlabLanguage _lang(String code) =>
    kBlabLanguages.firstWhere((l) => l.code == code);

Chat _chat({bool needsPracticeLanguageSelection = false}) => Chat(
  id: 'c1',
  partnerId: 'u2',
  partnerName: 'Nastia',
  partnerInitial: 'N',
  learningLanguage: _lang('es'), // you learn Spanish
  mode: ChatMode.practice,
  partnerNativeLanguage: _lang('es'),
  partnerLearningLanguage: _lang('nl'), // Nastia learns Dutch
  lastMessage: '',
  lastMessageTranslation: '',
  timestamp: DateTime.parse('2026-06-10T00:00:00Z'),
  unreadCount: 0,
  needsPracticeLanguageSelection: needsPracticeLanguageSelection,
);

void main() {
  testWidgets('first-message prompt waits until required language is chosen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FirstMessageEmptyState(
            chat: _chat(needsPracticeLanguageSelection: true),
          ),
        ),
      ),
    );
    expect(find.text('No messages here yet…'), findsNothing);
    expect(find.text('Send any message to start.'), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FirstMessageEmptyState(chat: _chat())),
      ),
    );
    expect(find.text('No messages here yet…'), findsOneWidget);
    expect(find.text('Send any message to start.'), findsOneWidget);
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: FirstMessageEmptyState(chat: _chat())),
    ),
  );

  testWidgets(
    'new chat invites a first message without choosing either person’s language',
    (tester) async {
      await pump(tester);
      expect(find.text('No messages here yet…'), findsOneWidget);
      expect(find.text('You learn Spanish'), findsNothing);
      expect(find.text('Nastia learns Dutch'), findsNothing);
      expect(find.text('Send any message to start.'), findsOneWidget);
    },
  );

  testWidgets(
    'has no flags, no exchange card, no pointer icon, no "connected"',
    (tester) async {
      await pump(tester);
      expect(find.byType(ExchangeCard), findsNothing);
      expect(find.byIcon(Icons.swap_vert), findsNothing);
      expect(find.text('🇪🇸'), findsNothing);
      expect(find.text('🇳🇱'), findsNothing);
      expect(find.textContaining('connected'), findsNothing);
    },
  );

  testWidgets('wraps the copy in a styled (decorated) container', (
    tester,
  ) async {
    await pump(tester);
    expect(
      find.byWidgetPredicate(
        (w) => w is Container && w.decoration is BoxDecoration,
      ),
      findsOneWidget,
      reason: 'the empty-state copy should sit in a card-like container',
    );
  });
}
