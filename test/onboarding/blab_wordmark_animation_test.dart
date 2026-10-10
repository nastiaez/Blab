import 'package:blab/features/onboarding/widgets/blab_wordmark_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
