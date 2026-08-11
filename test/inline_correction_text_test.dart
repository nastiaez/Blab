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

  testWidgets('tapping corrected text opens the word popup', (tester) async {
    // 'shop' -> 'store' is a trailing single-word replacement, so the
    // corrected segment is isolated as its own tap target: " store".
    await tester.pumpWidget(
      harness(originalText: 'I go to shop', correctedText: 'I go to store'),
    );

    expect(find.text('store'), findsNothing);

    await tester.tap(find.text(' store'));
    await tester.pumpAndSettle();

    // Word popup echoes the (trimmed) tapped word.
    expect(find.text('store'), findsOneWidget);
    expect(find.text(explanationText), findsNothing);
  });

  testWidgets('tapping struck-through text opens the explanation popup', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(originalText: 'I goed', correctedText: 'I went'),
    );

    expect(find.text(explanationText), findsNothing);

    await tester.tap(find.text('goed'));
    await tester.pumpAndSettle();

    expect(find.text(explanationText), findsOneWidget);
    // Explanation popup, not the word popup — no echoed struck word as a
    // standalone popup "headline".
    expect(find.text('went'), findsNothing);
  });

  testWidgets('tapping struck-through text with no explanation does nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(originalText: 'I goed', correctedText: 'I went', explanation: null),
    );

    await tester.tap(find.text('goed'));
    await tester.pumpAndSettle();

    expect(find.text(explanationText), findsNothing);
  });

  testWidgets('every non-whitespace segment gets its own tap target', (
    tester,
  ) async {
    // 'a b c d' -> 'x b y d' produces four segments: struck 'a', corrected
    // ' x b ', struck 'c', corrected ' y d'. The two struck segments are
    // single letters — still each get their own GlobalKey-measured hit
    // area via the per-segment Padding breathing room (MessageText's
    // trick), rather than sharing one recognizer.
    await tester.pumpWidget(
      harness(originalText: 'a b c d', correctedText: 'x b y d'),
    );

    // First struck segment.
    await tester.tap(find.text('a'));
    await tester.pumpAndSettle();
    expect(find.text(explanationText), findsOneWidget);

    // Dismiss via the popup's barrier (bottom-right, clear of the card).
    await tester.tapAt(const Offset(780, 580));
    await tester.pumpAndSettle();
    expect(find.text(explanationText), findsNothing);

    // Second, independent struck segment.
    await tester.tap(find.text('c'));
    await tester.pumpAndSettle();
    expect(find.text(explanationText), findsOneWidget);
    await tester.tapAt(const Offset(780, 580));
    await tester.pumpAndSettle();

    // First corrected segment.
    await tester.tap(find.text(' x b '));
    await tester.pumpAndSettle();
    expect(find.text('x b'), findsOneWidget);
    await tester.tapAt(const Offset(780, 580));
    await tester.pumpAndSettle();

    // Second, independent corrected segment.
    await tester.tap(find.text(' y d'));
    await tester.pumpAndSettle();
    expect(find.text('y d'), findsOneWidget);
  });
}
