import 'package:blab/features/chat/widgets/chat_composer_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('attach button lives inside the message container on the right', (
    tester,
  ) async {
    var attached = false;
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: ChatComposerInput(
                controller: controller,
                hintText: 'Message',
                maxLength: 2000,
                autofocus: false,
                attachTooltip: 'Attach',
                onAttach: () => attached = true,
              ),
            ),
          ),
        ),
      ),
    );

    final containerRect = tester.getRect(
      find.byKey(const ValueKey('composer-message-container')),
    );
    final textFieldRect = tester.getRect(
      find.byKey(const ValueKey('composer-message-text-field')),
    );
    final attachRect = tester.getRect(
      find.byKey(const ValueKey('composer-attach-button')),
    );

    expect(attachRect.left, greaterThan(textFieldRect.right));
    expect(attachRect.right, lessThanOrEqualTo(containerRect.right));
    expect(attachRect.top, greaterThanOrEqualTo(containerRect.top));
    expect(attachRect.bottom, lessThanOrEqualTo(containerRect.bottom));

    await tester.tap(find.byKey(const ValueKey('composer-attach-button')));
    expect(attached, isTrue);
  });
}
