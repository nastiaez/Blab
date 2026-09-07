import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/widgets/chat_composer_input.dart';
import 'package:blab/shared/widgets/blab_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('send artwork renders at 20 px', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatSendButton(
            canSend: true,
            isPractice: true,
            tooltip: 'Send',
            onSend: () {},
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('composer-send-icon'))),
      const Size.square(20),
    );
  });

  testWidgets('send button shadow appears in Practice only', (tester) async {
    Future<BoxDecoration> pumpButton({
      required bool isPractice,
      bool canSend = true,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatSendButton(
              canSend: canSend,
              isPractice: isPractice,
              tooltip: 'Send',
              onSend: () {},
            ),
          ),
        ),
      );
      return tester
              .widget<DecoratedBox>(
                find.byKey(const ValueKey('composer-send-decoration')),
              )
              .decoration
          as BoxDecoration;
    }

    final normal = await pumpButton(isPractice: false);
    final practice = await pumpButton(isPractice: true, canSend: false);

    expect(normal.boxShadow, isNull);
    expect(practice.boxShadow, hasLength(1));
    expect(practice.boxShadow!.single.color, const Color(0x2E231208));
    expect(practice.boxShadow!.single.offset, const Offset(0, 3));
    expect(practice.boxShadow!.single.blurRadius, 8);
    expect(practice.boxShadow!.single.spreadRadius, 0);
    final disabledFill =
        tester
                .widget<AnimatedContainer>(
                  find.byKey(const ValueKey('composer-send-fill')),
                )
                .decoration
            as BoxDecoration;
    final disabledIcon = tester.widget<BlabIcon>(
      find.descendant(
        of: find.byKey(const ValueKey('composer-send-icon')),
        matching: find.byType(BlabIcon),
      ),
    );
    expect(disabledFill.color, BlabColors.sendButton.withValues(alpha: 0.4));
    expect(disabledIcon.color, Colors.white);
  });

  testWidgets(
    'practice hint keeps the composer at the same one-row height as Message',
    (tester) async {
      final controllers = <TextEditingController>[];
      addTearDown(() {
        for (final controller in controllers) {
          controller.dispose();
        }
      });

      Future<double> pumpComposer(String hintText) async {
        final controller = TextEditingController();
        controllers.add(controller);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 284,
                  child: ChatComposerInput(
                    controller: controller,
                    hintText: hintText,
                    maxLength: 2000,
                    autofocus: false,
                    attachTooltip: 'Attach',
                    onAttach: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        return tester
            .getSize(find.byKey(const ValueKey('composer-message-container')))
            .height;
      }

      final normalHeight = await pumpComposer('Message');
      const practiceHint = 'Type in Ukrainian or English';
      final practiceHeight = await pumpComposer(practiceHint);

      expect(practiceHeight, normalHeight);
    },
  );

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
    final attachIcon = tester.widget<BlabIcon>(
      find.descendant(
        of: find.byKey(const ValueKey('composer-attach-button')),
        matching: find.byType(BlabIcon),
      ),
    );

    expect(attachRect.left, greaterThan(textFieldRect.right));
    expect(attachRect.right, lessThanOrEqualTo(containerRect.right));
    expect(attachRect.top, greaterThanOrEqualTo(containerRect.top));
    expect(attachRect.bottom, lessThanOrEqualTo(containerRect.bottom));
    expect(attachIcon.color, const Color(0xFF231208));

    await tester.tap(find.byKey(const ValueKey('composer-attach-button')));
    expect(attached, isTrue);
  });
}
