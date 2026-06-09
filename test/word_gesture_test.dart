import 'package:blab/features/chat/widgets/message_text.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the chat bubble's two competing gestures:
///   - tap a learning-language word  → word popup (US-018)
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

Widget _harness({required VoidCallback onLongPress}) {
  return ProviderScope(
    overrides: [ttsServiceProvider.overrideWithValue(_FakeTtsService())],
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: onLongPress,
            // onTap intentionally null — matches a non-failed bubble.
            child: const MessageText(
              text: 'காலை எப்படி',
              tokens: [
                MessageToken(
                    text: 'காலை', romanization: 'kālai', english: 'morning'),
                MessageToken(text: ' ', isContent: false),
                MessageToken(
                    text: 'எப்படி', romanization: 'eppadi', english: 'how'),
              ],
              languageCode: 'ta',
              style: TextStyle(fontSize: 16, color: Colors.black),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tapping a word opens the popup and does NOT long-press',
      (tester) async {
    var longPressed = false;
    await tester.pumpWidget(_harness(onLongPress: () => longPressed = true));

    await tester.tap(find.text('காலை'));
    await tester.pumpAndSettle();

    expect(find.text('morning'), findsOneWidget,
        reason: 'word popup should open on tap');
    expect(longPressed, isFalse,
        reason: 'a quick tap must not trigger the action sheet');
  });

  testWidgets('long-pressing a word opens the action sheet, NOT the popup',
      (tester) async {
    var longPressed = false;
    await tester.pumpWidget(_harness(onLongPress: () => longPressed = true));

    await tester.longPress(find.text('காலை'));
    await tester.pumpAndSettle();

    expect(longPressed, isTrue,
        reason: 'holding the word must trigger the action sheet');
    expect(find.text('morning'), findsNothing,
        reason: 'long-press must not also open the word popup');
  });
}
