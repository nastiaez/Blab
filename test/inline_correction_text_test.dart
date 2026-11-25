import 'package:blab/features/chat/widgets/inline_correction_text.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    List<MessageToken> correctedTokens = const [],
  }) {
    return ProviderScope(
      overrides: [ttsServiceProvider.overrideWithValue(_FakeTtsService())],
      child: MaterialApp(
        home: Scaffold(
          body: InlineCorrectionText(
            originalText: originalText,
            correctedText: correctedText,

            style: const TextStyle(fontSize: 16, color: Colors.black),
          ),
        ),
      ),
    );
  }

  Future<void> dismiss(WidgetTester tester) async {
    await tester.tapAt(const Offset(780, 580));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping corrected chat text never opens word help', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(originalText: 'I go to shop', correctedText: 'I go to store'),
    );

    expect(find.text('store'), findsOneWidget);

    await tester.tap(find.text('store'));
    await tester.pumpAndSettle();

    expect(find.text('store'), findsOneWidget);
    expect(find.text(explanationText), findsNothing);
  });

  testWidgets('corrected chat words do not expose provider gloss', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        originalText: 'Ich habe gestern gehen.',
        correctedText: 'Ich bin gestern gegangen.',
        correctedTokens: const [
          MessageToken(text: 'Ich', gloss: 'I'),
          MessageToken(text: ' bin', gloss: 'am'),
          MessageToken(text: ' gestern', gloss: 'yesterday'),
          MessageToken(text: ' gegangen.', gloss: 'went'),
        ],
      ),
    );

    await tester.tap(find.text('bin'));
    await tester.pumpAndSettle();

    expect(find.text('am'), findsNothing);
  });

  testWidgets('corrected word uses semibold emphasis', (tester) async {
    await tester.pumpWidget(
      harness(originalText: 'I goed', correctedText: 'I went'),
    );

    final inline = tester.widget<Text>(
      find.byKey(const ValueKey('inline-correction')),
    );
    final rootSpan = inline.textSpan! as TextSpan;
    final correctedSpan = rootSpan.children!
        .whereType<WidgetSpan>()
        .map((span) => span.child)
        .whereType<Padding>()
        .map((padding) => padding.child)
        .whereType<Text>()
        .firstWhere((text) => text.textSpan?.toPlainText() == 'went');
    expect(correctedSpan.textSpan?.style?.fontWeight, FontWeight.w600);
  });

  testWidgets('tapping struck-through text does not open an explanation', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(originalText: 'I goed', correctedText: 'I went'),
    );

    expect(find.text(explanationText), findsNothing);
    expect(find.text('went'), findsOneWidget);

    await tester.tap(find.text('goed'));
    await tester.pumpAndSettle();

    expect(find.text(explanationText), findsNothing);
    expect(find.text('went'), findsOneWidget);
  });

  testWidgets('every word in a merged corrected run remains non-interactive '
      '(regression)', (tester) async {
    await tester.pumpWidget(
      harness(
        originalText: 'I goed to shop yesterday',
        correctedText: 'I went to the shop yesterday',
      ),
    );

    for (final word in ['went', 'to', 'the', 'shop', 'yesterday']) {
      expect(
        find.text(word),
        findsOneWidget,
        reason: '"$word" retains its existing paint span',
      );
    }
    expect(find.text('went to the shop yesterday'), findsNothing);

    await tester.tap(find.text('shop'));
    await tester.pumpAndSettle();

    expect(find.text('shop'), findsOneWidget);
    expect(find.text('went'), findsOneWidget);
    expect(find.text('yesterday'), findsOneWidget);
    expect(find.text('went to the shop yesterday'), findsNothing);
  });

  testWidgets('all correction runs remain non-interactive', (tester) async {
    await tester.pumpWidget(
      harness(originalText: 'a b c d', correctedText: 'x b y d'),
    );

    await tester.tap(find.text('a'));
    await tester.pumpAndSettle();
    expect(find.text(explanationText), findsNothing);

    await tester.tap(find.text('c'));
    await tester.pumpAndSettle();
    expect(find.text(explanationText), findsNothing);

    await tester.tap(find.text('x'));
    await tester.pumpAndSettle();
    expect(find.text('x'), findsOneWidget);
    await dismiss(tester);

    await tester.tap(find.text('b'));
    await tester.pumpAndSettle();
    expect(find.text('b'), findsOneWidget);
    await dismiss(tester);

    await tester.tap(find.text('y'));
    await tester.pumpAndSettle();
    expect(find.text('y'), findsOneWidget);
    await dismiss(tester);

    await tester.tap(find.text('d'));
    await tester.pumpAndSettle();
    expect(find.text('d'), findsOneWidget);
  });

  testWidgets('romanized chat correction never opens native reference', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        originalText: 'வணகம',
        correctedText: 'vanakkam',
        correctedTokens: const [
          MessageToken(
            text: 'vanakkam',
            romanization: 'வணக்கம்',
            nativeText: 'வணக்கம்',
            gloss: 'hello',
          ),
        ],
      ),
    );

    await tester.tap(find.text('vanakkam'));
    await tester.pumpAndSettle();
    expect(find.text('வணக்கம்'), findsNothing);
    expect(find.text('hello'), findsNothing);
  });
}
