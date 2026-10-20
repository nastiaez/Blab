import 'package:blab/features/onboarding/widgets/blab_wordmark_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a has a solo beat before l joins', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BlabWordmarkAnimation()));
    await tester.pump(BlabWordmarkAnimation.handoffHold);
    await tester.pump(const Duration(milliseconds: 250));
    Opacity letterOpacity(String key) => tester.widget<Opacity>(
      find
          .ancestor(of: find.byKey(Key(key)), matching: find.byType(Opacity))
          .first,
    );
    expect(letterOpacity('blab-l').opacity, 0);
    expect(letterOpacity('blab-first-b').opacity, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(letterOpacity('blab-l').opacity, greaterThan(0));
  });

  testWidgets('faster launch completes within 1.45 seconds without replay', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(home: BlabWordmarkAnimation(onCompleted: () => completed++)),
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump(const Duration(milliseconds: 16));
    expect(completed, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(completed, 1);
  });

  testWidgets('wordmark assembles once and reports completion', (tester) async {
    var completionCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BlabWordmarkAnimation(
              onCompleted: () => completionCount += 1,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('blab-a')), findsOneWidget);
    expect(find.byKey(const Key('blab-l')), findsOneWidget);
    expect(find.byKey(const Key('blab-first-b')), findsOneWidget);
    expect(find.byKey(const Key('blab-last-b')), findsOneWidget);
    expect(completionCount, 0);

    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(BlabWordmarkAnimation.handoffHold);
    await tester.pump(BlabWordmarkAnimation.motionDuration);
    await tester.pump(const Duration(milliseconds: 16));

    expect(completionCount, 1);
    expect(tester.takeException(), isNull);
  });
}
