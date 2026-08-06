import 'package:blab/features/chat/widgets/message_reaction_bar.dart';
import 'package:blab/shared/models/message_reaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reaction bar renders counts and highlights my reaction', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageReactionBar(
            reactions: const [
              MessageReactionSummary(emoji: '❤️', count: 2, reactedByMe: true),
              MessageReactionSummary(emoji: '😂', count: 1, reactedByMe: false),
            ],
            isOutgoing: false,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('❤️ 2'), findsOneWidget);
    expect(find.text('😂'), findsOneWidget);
    expect(find.byKey(const ValueKey('my-reaction-❤️')), findsOneWidget);
  });
}
