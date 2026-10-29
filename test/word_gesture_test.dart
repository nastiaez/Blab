import 'package:blab/features/chat/widgets/message_interaction_target.dart';
import 'package:blab/features/chat/widgets/message_text.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// BLA-17 message taps own text and padding; held presses have no entry.
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
                enableWordLookup: false,
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
  testWidgets('tapping message text opens actions without word popup', (
    tester,
  ) async {
    var longPressed = false;
    await tester.pumpWidget(
      _harness(onLongPress: (_, _) => longPressed = true),
    );

    await tester.tapAt(tester.getCenter(find.byType(MessageText)));
    await tester.pumpAndSettle();

    expect(
      find.text('morning'),
      findsNothing,
      reason: 'message text must not open word lookup',
    );
    expect(longPressed, isTrue, reason: 'a quick tap opens message actions');
  });

  testWidgets('long-pressing message text opens neither actions nor popup', (
    tester,
  ) async {
    var longPressed = false;
    await tester.pumpWidget(
      _harness(onLongPress: (_, _) => longPressed = true),
    );

    await tester.longPress(find.byType(MessageText));
    await tester.pumpAndSettle();

    expect(
      longPressed,
      isFalse,
      reason: 'held presses no longer enter message actions',
    );
    expect(
      find.text('morning'),
      findsNothing,
      reason: 'long-press must not also open the word popup',
    );
  });

  testWidgets('tapping non-word message space opens actions', (tester) async {
    var longPressed = false;
    await tester.pumpWidget(
      _harness(onLongPress: (_, _) => longPressed = true),
    );

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('message-padding'))) +
          const Offset(4, 4),
    );
    await tester.pump();

    expect(longPressed, isTrue);
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
    'failed message text opens actions not word help; retry stays separate',
    (tester) async {
      var failedTapped = false;
      var openedActions = false;
      await tester.pumpWidget(
        _harness(
          isFailed: true,
          onLongPress: (_, _) => openedActions = true,
          onFailedTap: () => failedTapped = true,
        ),
      );

      await tester.tapAt(tester.getCenter(find.byType(MessageText)));
      await tester.pumpAndSettle();

      expect(failedTapped, isFalse);
      expect(openedActions, isTrue);
      expect(find.text('morning'), findsNothing);
      expect(
        tester
            .widget<MouseRegion>(
              find
                  .ancestor(
                    of: find.byType(MessageText),
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
