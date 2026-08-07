import 'package:blab/features/chat/widgets/floating_reaction_row.dart';
import 'package:blab/features/chat/message_actions.dart'
    show kQuickMessageReactions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows every quick reaction plus a trailing more button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingReactionRow(
            selectedEmoji: null,
            onPick: (_) {},
            onMore: () {},
          ),
        ),
      ),
    );

    for (final emoji in kQuickMessageReactions) {
      expect(find.text(emoji), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('floating-reaction-more')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('floating-reaction-selected')),
      findsNothing,
    );
  });

  testWidgets('marks the viewer\'s existing reaction as selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingReactionRow(
            selectedEmoji: kQuickMessageReactions.first,
            onPick: (_) {},
            onMore: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('floating-reaction-selected')),
      findsOneWidget,
    );
  });

  testWidgets('tapping an emoji fires onPick with that emoji', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingReactionRow(
            selectedEmoji: null,
            onPick: (emoji) => picked = emoji,
            onMore: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text(kQuickMessageReactions[1]));
    expect(picked, kQuickMessageReactions[1]);
  });

  testWidgets('tapping the more button fires onMore', (tester) async {
    var moreTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingReactionRow(
            selectedEmoji: null,
            onPick: (_) {},
            onMore: () => moreTapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('floating-reaction-more')));
    expect(moreTapped, isTrue);
  });
}
