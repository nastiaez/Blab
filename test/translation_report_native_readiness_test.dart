import 'package:blab/features/chat/widgets/message_interaction_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final rich in [false, true]) {
    testWidgets(
      'native report readiness follows saved identity with rich=$rich',
      (tester) async {
        const identity = ValueKey(
          'message-row-reply-22555555-5555-4555-8555-555555555555',
        );
        var pressed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KeyedSubtree(
                key: identity,
                child: MessageInteractionTarget(
                  isFailed: false,
                  onLongPress: (_, _) => pressed = true,
                  onFailedTap: () {},
                  child: rich
                      ? RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(text: 'Ist es '),
                              TextSpan(text: 'distracting'),
                              TextSpan(text: ' for you?'),
                            ],
                          ),
                        )
                      : const Text('Ist es distracting for you?'),
                ),
              ),
            ),
          ),
        );
        final row = find.byKey(identity);
        expect(row, findsOneWidget);
        await tester.longPress(
          find
              .descendant(
                of: row,
                matching: find.byType(MessageInteractionTarget),
              )
              .first,
        );
        expect(pressed, true);
      },
    );
  }
}
