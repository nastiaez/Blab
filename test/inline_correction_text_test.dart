import 'package:blab/features/chat/widgets/inline_correction_text.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stand-in [TtsService] that never hits platform channels — keeps the
/// widget test free of `MissingPluginException`s. Mirrors the fake used in
/// test/word_gesture_test.dart / test/word_popup_test.dart.
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

void main() {
  const explanationText = 'Missing article "the" before a specific noun.';

  Widget harness({
    required String originalText,
    required String correctedText,
    String? explanation = explanationText,
  }) {
    return ProviderScope(
      overrides: [ttsServiceProvider.overrideWithValue(_FakeTtsService())],
      child: MaterialApp(
        home: Scaffold(
          body: InlineCorrectionText(
            originalText: originalText,
            correctedText: correctedText,
            learningLanguageCode: 'en',
            explanation: explanation,
            popupTopInset: 0,
            style: const TextStyle(fontSize: 16, color: Colors.black),
          ),
        ),
      ),
    );
  }

  /// Dismiss the currently-open popup by tapping its barrier, clear of
  /// where a small test-fixture card would land.
  Future<void> dismiss(WidgetTester tester) async {
    await tester.tapAt(const Offset(780, 580));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping corrected text opens the word popup', (tester) async {
    // 'shop' -> 'store' is a trailing single-word replacement, so the
    // corrected word is its own isolated segment already; this covers the
    // simple case before the merged-run regression test below.
    await tester.pumpWidget(
      harness(originalText: 'I go to shop', correctedText: 'I go to store'),
    );

    // Just the inline word, no popup yet.
    expect(find.text('store'), findsOneWidget);

    await tester.tap(find.text('store'));
    await tester.pumpAndSettle();

    // Inline word + popup echo.
    expect(find.text('store'), findsNWidgets(2));
    expect(find.text(explanationText), findsNothing);
  });

  testWidgets('tapping struck-through text opens the explanation popup', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(originalText: 'I goed', correctedText: 'I went'),
    );

    expect(find.text(explanationText), findsNothing);
    // Just the inline corrected word before any tap.
    expect(find.text('went'), findsOneWidget);

    await tester.tap(find.text('goed'));
    await tester.pumpAndSettle();

    expect(find.text(explanationText), findsOneWidget);
    // Explanation popup, not the word popup — 'went' must still only be
    // the one inline span, not also echoed as a popup headline.
    expect(find.text('went'), findsOneWidget);
  });

  testWidgets('tapping struck-through text with no explanation does nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        originalText: 'I goed',
        correctedText: 'I went',
        explanation: null,
      ),
    );

    await tester.tap(find.text('goed'));
    await tester.pumpAndSettle();

    expect(find.text(explanationText), findsNothing);
  });

  testWidgets(
    'every word in a merged corrected run gets its own tap target '
    '(regression)',
    (tester) async {
      // Regression for the bug the plan's own pseudocode had: a single
      // mistake in the middle of an otherwise-correct sentence leaves
      // correctionSegments() merging everything after it — "went to the
      // shop yesterday" — into ONE non-struck CorrectionSegment. Tapping
      // "shop" must still open a popup for just "shop", not hand the
      // whole five-word phrase to showWordPopup as a single "word".
      await tester.pumpWidget(
        harness(
          originalText: 'I goed to shop yesterday',
          correctedText: 'I went to the shop yesterday',
        ),
      );

      // Every word in the merged run is independently present as its own
      // tappable span, not fused into a single multi-word text node.
      for (final word in ['went', 'to', 'the', 'shop', 'yesterday']) {
        expect(
          find.text(word),
          findsOneWidget,
          reason: '"$word" should be its own tap target',
        );
      }
      // The merged phrase must never appear as a single text node.
      expect(find.text('went to the shop yesterday'), findsNothing);

      await tester.tap(find.text('shop'));
      await tester.pumpAndSettle();

      // Popup echoes just "shop" — inline span + popup headline.
      expect(find.text('shop'), findsNWidgets(2));
      // Neighboring words are untouched — still exactly one inline span
      // each, no popup echoing the whole phrase.
      expect(find.text('went'), findsOneWidget);
      expect(find.text('yesterday'), findsOneWidget);
      expect(find.text('went to the shop yesterday'), findsNothing);
    },
  );

  testWidgets('every non-whitespace segment gets its own tap target', (
    tester,
  ) async {
    // 'a b c d' -> 'x b y d' produces four CorrectionSegments: struck 'a',
    // corrected ' x b ', struck 'c', corrected ' y d'. Each single-letter
    // struck run AND each single-letter word inside a corrected run must
    // be independently tappable — not merged, not sharing a recognizer.
    await tester.pumpWidget(
      harness(originalText: 'a b c d', correctedText: 'x b y d'),
    );

    // First struck segment.
    await tester.tap(find.text('a'));
    await tester.pumpAndSettle();
    expect(find.text(explanationText), findsOneWidget);
    await dismiss(tester);

    // Second, independent struck segment.
    await tester.tap(find.text('c'));
    await tester.pumpAndSettle();
    expect(find.text(explanationText), findsOneWidget);
    await dismiss(tester);

    // First word of the corrected run ' x b '.
    await tester.tap(find.text('x'));
    await tester.pumpAndSettle();
    expect(find.text('x'), findsNWidgets(2));
    await dismiss(tester);

    // Second, independent word of the same corrected run — proves the run
    // wasn't fused into one "x b" tap target.
    await tester.tap(find.text('b'));
    await tester.pumpAndSettle();
    expect(find.text('b'), findsNWidgets(2));
    await dismiss(tester);

    // Words from the other corrected run, ' y d'.
    await tester.tap(find.text('y'));
    await tester.pumpAndSettle();
    expect(find.text('y'), findsNWidgets(2));
    await dismiss(tester);

    await tester.tap(find.text('d'));
    await tester.pumpAndSettle();
    expect(find.text('d'), findsNWidgets(2));
  });
}
