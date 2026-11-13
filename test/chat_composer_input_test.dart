import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/widgets/chat_composer_input.dart';
import 'package:blab/shared/widgets/blab_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opaque direct disabled fill matches Flutter compositing rounding', () {
    final composited = Color.alphaBlend(
      const Color(0xFF46281C).withValues(alpha: 0.4),
      const Color(0xFFFFFCF8),
    );
    expect(composited.toARGB32(), 0xFFB5A7A0);
  });
  test(
    'branded send asset preserves the exact approved upright geometry',
    () async {
      final svg = await rootBundle.loadString(
        'assets/icons/chat-send-branded.svg',
      );
      expect(
        svg.trim(),
        '<svg width="24" height="24" viewBox="-85 -13 170 170" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M-42.423 88.524C-5.072 69.456 0 0 0 0C0 0 5.072 69.456 42.423 88.524" stroke="white" stroke-width="18"/><path d="M0 143.497V0" stroke="white" stroke-width="18"/></svg>',
      );
    },
  );

  for (final group in [false, true]) {
    for (final practice in [false, true]) {
      for (final enabled in [false, true]) {
        testWidgets(
          'send group=$group practice=$practice enabled=$enabled preserves contract',
          (tester) async {
            var sends = 0;
            final semantics = tester.ensureSemantics();
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: ChatSendButton(
                      canSend: enabled,
                      isPractice: practice,
                      groupConversation: group,
                      tooltip: 'Send message',
                      onSend: () => sends++,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.getSize(find.byType(ChatSendButton)),
              Size.square(group ? 48 : 44),
            );
            expect(
              tester.getSize(find.byKey(const ValueKey('composer-send-icon'))),
              const Size.square(24),
            );
            final icon = tester.widget<BlabIcon>(find.byType(BlabIcon));
            expect(icon.name, 'chat-send-branded');
            expect(icon.size, 24);
            expect(icon.color, Colors.white);
            final fill =
                tester
                        .widget<AnimatedContainer>(
                          find.byKey(const ValueKey('composer-send-fill')),
                        )
                        .decoration!
                    as BoxDecoration;
            expect(
              fill.color,
              enabled
                  ? BlabColors.sendButton
                  : (group ? const Color(0xFFB3A69D) : const Color(0xFFB5A7A0)),
            );
            expect(fill.color!.a, 1);
            final decoration =
                tester
                        .widget<DecoratedBox>(
                          find.byKey(
                            const ValueKey('composer-send-decoration'),
                          ),
                        )
                        .decoration
                    as BoxDecoration;
            if (practice) {
              expect(decoration.boxShadow, const [
                BoxShadow(
                  color: Color(0x2E231208),
                  offset: Offset(0, 3),
                  blurRadius: 8,
                ),
              ]);
            } else {
              expect(decoration.boxShadow, isNull);
            }
            expect(find.byTooltip('Send message'), findsOneWidget);
            final button = tester.widget<IconButton>(find.byType(IconButton));
            expect(button.onPressed == null, !enabled);
            expect(
              find.descendant(
                of: find.byKey(const ValueKey('composer-send-icon')),
                matching: find.byType(Transform),
              ),
              findsNothing,
            );
            await tester.tap(find.byType(ChatSendButton));
            expect(sends, enabled ? 1 : 0);
            semantics.dispose();
          },
        );
      }
    }
  }

  testWidgets('send artwork renders at approved 24 px', (tester) async {
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
      const Size.square(24),
    );
  });

  testWidgets(
    'Practice shadow stays under opaque enabled and disabled circles',
    (tester) async {
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
      final practice = await pumpButton(isPractice: true);

      expect(normal.boxShadow, isNull);
      expect(practice.boxShadow, hasLength(1));
      expect(practice.boxShadow!.single.color, const Color(0x2E231208));
      expect(practice.boxShadow!.single.offset, const Offset(0, 3));
      expect(practice.boxShadow!.single.blurRadius, 8);
      expect(practice.boxShadow!.single.spreadRadius, 0);
      final disabled = await pumpButton(isPractice: true, canSend: false);
      expect(disabled.boxShadow, practice.boxShadow);
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
      expect(disabledFill.color, const Color(0xFFB5A7A0));
      expect(disabledIcon.color, Colors.white);
    },
  );

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
