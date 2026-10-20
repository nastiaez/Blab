import 'package:blab/features/chat/widgets/message_reaction_bar.dart';
import 'package:blab/shared/models/message_reaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reaction bar renders counts and highlights my reaction', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageReactionBar(
            reactions: const [
              MessageReactionSummary(emoji: '❤️', count: 2, reactedByMe: true),
              MessageReactionSummary(emoji: '😂', count: 1, reactedByMe: false),
            ],
            isOutgoing: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('❤️'), findsOneWidget);
    expect(find.text('😂'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byKey(const ValueKey('my-reaction-❤️')), findsOneWidget);

    await tester.tap(find.text('❤️'));
    expect(tapped, isTrue);
    final pill = tester.getRect(
      find.byKey(const ValueKey('message-reaction-pill')),
    );
    expect(pill.width, greaterThan(pill.height));
    expect(pill.height, 32);
    expect(
      tester.getCenter(find.text('3')).dx,
      greaterThan(tester.getCenter(find.text('😂')).dx),
    );
    expect(find.text('2'), findsNothing);
  });
}
