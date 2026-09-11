import 'package:blab/features/chat/widgets/floating_reaction_row.dart';
import 'package:blab/features/chat/message_actions.dart'
    show kQuickMessageReactions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  bool visible = true,
  bool disableAnimations = false,
  Alignment scaleAlignment = Alignment.center,
  ValueChanged<String>? onPick,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: FloatingReactionRow(
          visible: visible,
          scaleAlignment: scaleAlignment,
          selectedEmoji: null,
          onPick: onPick ?? (_) {},
          onMore: () {},
        ),
      ),
    ),
  );
}

double _scale(WidgetTester tester, String key) {
  return tester.widget<ScaleTransition>(find.byKey(ValueKey(key))).scale.value;
}

double _opacity(WidgetTester tester) {
  return tester
      .widget<FadeTransition>(
        find.byKey(const ValueKey('floating-reaction-container-opacity')),
      )
      .opacity
      .value;
}

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
    expect(
      find.byKey(const ValueKey('floating-reaction-more')),
      findsOneWidget,
    );
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

  testWidgets('tapping an emoji fires onPick with that emoji', (tester) async {
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

  testWidgets(
    'container enters from its message-side anchor with soft overshoot',
    (tester) async {
      await tester.pumpWidget(_harness(scaleAlignment: Alignment.centerRight));

      final transition = tester.widget<ScaleTransition>(
        find.byKey(const ValueKey('floating-reaction-container-scale')),
      );
      expect(transition.alignment, Alignment.centerRight);
      expect(transition.scale.value, closeTo(0.88, 0.001));
      expect(_opacity(tester), 0);

      await tester.pump(const Duration(milliseconds: 190));
      expect(
        _scale(tester, 'floating-reaction-container-scale'),
        greaterThan(1),
      );

      await tester.pump(const Duration(milliseconds: 140));
      expect(
        _scale(tester, 'floating-reaction-container-scale'),
        closeTo(1, 0.001),
      );
      expect(_opacity(tester), 1);
    },
  );

  testWidgets('reaction controls settle in at 30 millisecond intervals', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pump(const Duration(milliseconds: 45));

    final first = _scale(tester, 'floating-reaction-item-0');
    final second = _scale(tester, 'floating-reaction-item-1');
    final third = _scale(tester, 'floating-reaction-item-2');
    expect(first, greaterThan(second));
    expect(second, greaterThan(third));
    expect(third, closeTo(0.72, 0.001));

    await tester.pump(const Duration(milliseconds: 285));
    for (var index = 0; index < kQuickMessageReactions.length + 1; index++) {
      expect(
        _scale(tester, 'floating-reaction-item-$index'),
        closeTo(1, 0.001),
      );
    }
  });

  testWidgets('dismissal fades for 150 milliseconds without shrinking', (
    tester,
  ) async {
    var visible = true;
    late StateSetter setHostState;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setHostState = setState;
          return _harness(visible: visible);
        },
      ),
    );
    await tester.pumpAndSettle();

    setHostState(() => visible = false);
    await tester.pump();
    expect(find.text(kQuickMessageReactions.first).hitTestable(), findsNothing);

    await tester.pump(const Duration(milliseconds: 75));
    expect(_opacity(tester), closeTo(0.5, 0.08));
    expect(_scale(tester, 'floating-reaction-container-scale'), 1);

    await tester.pump(const Duration(milliseconds: 75));
    expect(_opacity(tester), 0);
    expect(_scale(tester, 'floating-reaction-container-scale'), 1);
  });

  testWidgets('reduced motion removes scale, overshoot, and stagger', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(disableAnimations: true));

    expect(_opacity(tester), 1);
    expect(_scale(tester, 'floating-reaction-container-scale'), 1);
    for (var index = 0; index < kQuickMessageReactions.length + 1; index++) {
      expect(_scale(tester, 'floating-reaction-item-$index'), 1);
    }
    expect(tester.hasRunningAnimations, isFalse);
  });
}
