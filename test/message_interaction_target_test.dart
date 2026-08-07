import 'package:blab/features/chat/widgets/message_interaction_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
