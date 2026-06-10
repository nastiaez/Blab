import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blab/features/chat/widgets/first_message_empty_state.dart';
import 'package:blab/features/invite/widgets/exchange_card.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/models/chat.dart';

BlabLanguage _lang(String code) =>
    kBlabLanguages.firstWhere((l) => l.code == code);

Chat _chat() => Chat(
      id: 'c1',
      partnerId: 'u2',
      partnerName: 'Nastia',
      partnerInitial: 'N',
      learningLanguage: _lang('es'), // you learn Spanish
      partnerNativeLanguage: _lang('es'),
      partnerLearningLanguage: _lang('nl'), // Nastia learns Dutch
      lastMessage: '',
      lastMessageTranslation: '',
      timestamp: DateTime.parse('2026-06-10T00:00:00Z'),
      unreadCount: 0,
    );

void main() {
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: FirstMessageEmptyState(chat: _chat()))),
      );

  testWidgets('shows the two plain learn lines + start prompt', (tester) async {
    await pump(tester);
    expect(find.text('You learn Spanish'), findsOneWidget);
    expect(find.text('Nastia learns Dutch'), findsOneWidget);
    expect(find.text('Send any message to start.'), findsOneWidget);
  });

  testWidgets('has no flags, no exchange card, no pointer icon, no "connected"',
      (tester) async {
    await pump(tester);
    expect(find.byType(ExchangeCard), findsNothing);
    expect(find.byIcon(Icons.swap_vert), findsNothing);
    expect(find.text('🇪🇸'), findsNothing);
    expect(find.text('🇳🇱'), findsNothing);
    expect(find.textContaining('connected'), findsNothing);
  });
}
