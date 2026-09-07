import 'package:blab/features/chat/widgets/message_interaction_target.dart';
import 'package:blab/features/chat/widgets/message_text.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the chat bubble's two competing gestures:
///   - tap a learning-language word  → word popup (US-018)
///   - tap message padding           → nothing; no accidental action sheet
///   - long-press the bubble         → message action sheet (US-019/020,
///                                      now incl. Report from Step 3.6a)
///
/// Reproduces `_MessageRow`'s composition: an outer GestureDetector with
/// onLongPress wrapping the MessageText whose content tokens each carry a
/// TapGestureRecognizer. A quick tap must reach the word; a held press must
/// reach the long-press handler — never both.
class _FakeTtsService implements TtsService {
  @override
  Future<bool> isLanguageAvailable(String languageCode) async => false;
  @override
  Future<void> speak(String text, String languageCode) async {}
  @override
  Future<void> stop() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _harness({
  required void Function(Rect, Offset) onLongPress,
  VoidCallback? onFailedTap,
  VoidCallback? onSwipeReply,
  bool isFailed = false,
}) {
  return ProviderScope(
    overrides: [ttsServiceProvider.overrideWithValue(_FakeTtsService())],
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: MessageInteractionTarget(
            isFailed: isFailed,
            onLongPress: onLongPress,
            onFailedTap: onFailedTap ?? () {},
            onSwipeReply: onSwipeReply,
            child: const Padding(
              key: ValueKey('message-padding'),
              padding: EdgeInsets.all(20),
              child: MessageText(
                text: 'காலை எப்படி',
                tokens: [
                  MessageToken(
                    text: 'காலை',
                    romanization: 'kālai',
                    gloss: 'morning',
                  ),
                  MessageToken(text: ' ', isContent: false),
                  MessageToken(
                    text: 'எப்படி',
                    romanization: 'eppadi',
                    gloss: 'how',
                  ),
                ],
                languageCode: 'ta',
                style: TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tapping a word opens the popup and does NOT long-press', (
    tester,
  ) async {
    var longPressed = false;
    await tester.pumpWidget(
      _harness(onLongPress: (_, _) => longPressed = true),
    );

    await tester.tapAt(tester.getCenter(find.text('காலை')));
    await tester.pumpAndSettle();

    expect(
      find.text('morning'),
      findsOneWidget,
      reason: 'word popup should open on tap',
    );
    expect(
      longPressed,
      isFalse,
      reason: 'a quick tap must not trigger the action sheet',
    );
  });

  testWidgets('long-pressing a word opens the action sheet, NOT the popup', (
    tester,
  ) async {
    var longPressed = false;
    await tester.pumpWidget(
      _harness(onLongPress: (_, _) => longPressed = true),
    );

    await tester.longPress(find.text('காலை'));
    await tester.pumpAndSettle();

    expect(
      longPressed,
      isTrue,
      reason: 'holding the word must trigger the action sheet',
    );
    expect(
      find.text('morning'),
      findsNothing,
      reason: 'long-press must not also open the word popup',
    );
  });

  testWidgets('tapping non-word message space does not open the action sheet', (
    tester,
  ) async {
    var longPressed = false;
    await tester.pumpWidget(
      _harness(onLongPress: (_, _) => longPressed = true),
    );

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('message-padding'))) +
          const Offset(4, 4),
    );
    await tester.pump();

    expect(longPressed, isFalse);
    expect(find.text('Reply'), findsNothing);
  });

  testWidgets('swiping a delivered message left triggers reply', (
    tester,
  ) async {
    var replied = false;
    var longPressed = false;
    await tester.pumpWidget(
      _harness(
        onLongPress: (_, _) => longPressed = true,
        onSwipeReply: () => replied = true,
      ),
    );

    await tester.dragFrom(
      tester.getCenter(find.byType(MessageInteractionTarget)),
      const Offset(-90, 0),
    );
    await tester.pumpAndSettle();

    expect(replied, isTrue);
    expect(longPressed, isFalse);
    expect(find.text('Reply'), findsNothing);
  });

  testWidgets('a mostly vertical gesture does not trigger reply', (
    tester,
  ) async {
    var replied = false;
    await tester.pumpWidget(
      _harness(onLongPress: (_, _) {}, onSwipeReply: () => replied = true),
    );

    await tester.dragFrom(
      tester.getCenter(find.byType(MessageInteractionTarget)),
      const Offset(-90, -70),
    );
    await tester.pumpAndSettle();

    expect(replied, isFalse);
  });

  testWidgets('a short horizontal movement does not trigger reply', (
    tester,
  ) async {
    var replied = false;
    await tester.pumpWidget(
      _harness(onLongPress: (_, _) {}, onSwipeReply: () => replied = true),
    );

    await tester.dragFrom(
      tester.getCenter(find.byType(MessageInteractionTarget)),
      const Offset(-75, 0),
    );
    await tester.pumpAndSettle();

    expect(replied, isFalse);
  });

  testWidgets('swiping a failed message does not trigger reply', (
    tester,
  ) async {
    var replied = false;
    await tester.pumpWidget(
      _harness(
        isFailed: true,
        onLongPress: (_, _) {},
        onSwipeReply: () => replied = true,
      ),
    );

    await tester.dragFrom(
      tester.getCenter(find.byType(MessageInteractionTarget)),
      const Offset(90, 0),
    );
    await tester.pumpAndSettle();

    expect(replied, isFalse);
  });

  testWidgets(
    'failed message text still opens word help; retry stays in its status row',
    (tester) async {
      var failedTapped = false;
      await tester.pumpWidget(
        _harness(
          isFailed: true,
          onLongPress: (_, _) {},
          onFailedTap: () => failedTapped = true,
        ),
      );

      await tester.tapAt(tester.getCenter(find.text('காலை')));
      await tester.pumpAndSettle();

      expect(failedTapped, isFalse);
      expect(find.text('morning'), findsOneWidget);
      expect(
        tester
            .widget<MouseRegion>(
              find
                  .ancestor(
                    of: find.text('காலை'),
                    matching: find.byType(MouseRegion),
                  )
                  .first,
            )
            .cursor,
        SystemMouseCursors.click,
      );
    },
  );
}
