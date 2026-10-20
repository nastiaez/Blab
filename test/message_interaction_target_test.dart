import 'package:blab/features/chat/widgets/message_interaction_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final failed in [false, true]) {
    testWidgets('double tap respects child word taps and failed=$failed', (
      tester,
    ) async {
      var hearts = 0;
      var words = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageInteractionTarget(
              isFailed: failed,
              onDoubleTap: () => hearts++,
              onLongPress: (_, _) {},
              onFailedTap: () {},
              child: GestureDetector(
                onTap: () => words++,
                child: const SizedBox(
                  width: 180,
                  height: 80,
                  child: Text('word'),
                ),
              ),
            ),
          ),
        ),
      );
      final word = find.text('word');
      await tester.tap(word);
      await tester.pump(const Duration(milliseconds: 400));
      expect(words, 1);
      expect(hearts, 0);
      await tester.tap(word);
      await tester.pump(const Duration(milliseconds: 70));
      await tester.tap(word);
      await tester.pump(const Duration(milliseconds: 400));
      expect(hearts, failed ? 0 : 1);
      expect(words, failed ? 3 : 1);
      await tester.longPress(word);
      await tester.pumpAndSettle();
      expect(hearts, failed ? 0 : 1);
    });
  }

  testWidgets('long press reports the bubble rect and press position', (
    tester,
  ) async {
    Rect? capturedRect;
    Offset? capturedPosition;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 100, left: 20),
              child: MessageInteractionTarget(
                isFailed: false,
                onLongPress: (rect, position) {
                  capturedRect = rect;
                  capturedPosition = position;
                },
                onFailedTap: () {},
                child: const SizedBox(width: 150, height: 60),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.byType(MessageInteractionTarget));
    await tester.pumpAndSettle();

    expect(capturedRect, isNotNull);
    expect(capturedRect, tester.getRect(find.byType(MessageInteractionTarget)));
    expect(capturedPosition, isNotNull);
    // The synthetic long-press lands at the target's center.
    expect(capturedPosition!.dx, closeTo(capturedRect!.center.dx, 1));
    expect(capturedPosition!.dy, closeTo(capturedRect!.center.dy, 1));
  });
}
