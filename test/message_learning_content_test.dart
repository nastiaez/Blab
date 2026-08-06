import 'package:blab/features/chat/widgets/inline_correction_text.dart';
import 'package:blab/features/chat/widgets/message_learning_content.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MessageTranslation result({
    required String learning,
    required String interfaceText,
    required String source,
    String learningCode = 'de',
    String interfaceCode = 'en',
    LearningAidMode mode = LearningAidMode.translation,
    String? explanation,
    CorrectionConfidence? confidence,
  }) => MessageTranslation(
    translation: learning,
    interfaceText: interfaceText,
    interfaceLang: interfaceCode,
    sourceLang: source,
    tokens: [
      MessageToken(text: learning, gloss: interfaceText, isContent: true),
    ],
    mode: mode,
    explanation: explanation,
    confidence: confidence,
  );

  Widget host(
    AsyncValue<MessageTranslation>? translation, {
    String authoredText = 'What are you doing?',
    bool isOutgoing = false,
    bool showTranslation = true,
    String learningCode = 'de',
    String interfaceCode = 'en',
    VoidCallback? onRetry,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MessageLearningContent(
          authoredText: authoredText,
          translation: translation,
          showTranslation: showTranslation,
          learningLanguageCode: learningCode,
          interfaceLanguageCode: interfaceCode,
          isOutgoing: isOutgoing,
          popupTopInset: 0,
          unavailableText: 'Translation unavailable',
          retryText: 'Retry',
          onRetry: onRetry,
        ),
      ),
    );
  }

  void expectWords(Iterable<String> words) {
    for (final word in words) {
      expect(find.text(word), findsOneWidget);
    }
  }

  test(
    'inline correction keeps cosmetic edits clean and strikes replacement',
    () {
      expect(
        correctionSegments(
          'was machen du',
          'Was machst du?',
        ).map((segment) => (segment.text, segment.struck)).toList(),
        [('Was ', false), ('machen', true), (' machst du?', false)],
      );
    },
  );

  testWidgets('author sees inline learning correction without extra label', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AsyncData(
          result(
            learning: 'Was machst du?',
            interfaceText: 'What are you doing?',
            source: 'de',
            mode: LearningAidMode.correction,
            explanation: 'The verb must agree with du.',
            confidence: CorrectionConfidence.high,
          ),
        ),
        authoredText: 'was machen du',
        isOutgoing: true,
      ),
    );

    expect(find.byKey(const ValueKey('inline-correction')), findsOneWidget);
    expect(find.text('What are you doing?'), findsOneWidget);
    expect(find.textContaining('Correction:'), findsNothing);
    expect(find.textContaining('Possible correction:'), findsNothing);
    expect(find.text('was machen du'), findsNothing);
  });

  testWidgets('recipient sees clean correction without author coaching marks', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AsyncData(
          result(
            learning: 'What are you doing?',
            interfaceText: 'Що ти робиш?',
            source: 'en',
            learningCode: 'en',
            interfaceCode: 'uk',
            mode: LearningAidMode.correction,
            explanation: 'Use are with you.',
            confidence: CorrectionConfidence.high,
          ),
        ),
        authoredText: 'What is you doing?',
        learningCode: 'en',
        interfaceCode: 'uk',
      ),
    );

    expect(find.byKey(const ValueKey('inline-correction')), findsNothing);
    expectWords(const ['What', 'are', 'you', 'doing']);
    expect(find.text('Що ти робиш?'), findsOneWidget);
    expect(find.textContaining('Correction:'), findsNothing);
    expect(find.text('What is you doing?'), findsNothing);
  });

  testWidgets(
    'recipient learning source language sees only corrected message',
    (tester) async {
      await tester.pumpWidget(
        host(
          AsyncData(
            result(
              learning: 'I went to the shop yesterday.',
              interfaceText: 'I went to the shop yesterday.',
              source: 'en',
              learningCode: 'en',
              interfaceCode: 'en',
              mode: LearningAidMode.correction,
              explanation: 'Use went as the past tense of go.',
              confidence: CorrectionConfidence.high,
            ),
          ),
          authoredText: 'I goed to the shop yesterday.',
          learningCode: 'en',
          interfaceCode: 'en',
        ),
      );

      expect(find.byKey(const ValueKey('inline-correction')), findsNothing);
      expectWords(const ['I', 'went', 'to', 'the', 'shop', 'yesterday']);
      expect(find.text('I goed to the shop yesterday.'), findsNothing);
    },
  );

  testWidgets(
    'recipient learning another language gets corrected source below',
    (tester) async {
      await tester.pumpWidget(
        host(
          AsyncData(
            result(
              learning: 'Fui a la tienda ayer.',
              interfaceText: 'I went to the shop yesterday.',
              source: 'en',
              learningCode: 'es',
              interfaceCode: 'en',
              mode: LearningAidMode.correction,
              explanation: 'Use went as the past tense of go.',
              confidence: CorrectionConfidence.high,
            ),
          ),
          authoredText: 'I goed to the shop yesterday.',
          learningCode: 'es',
          interfaceCode: 'en',
        ),
      );

      expect(find.byKey(const ValueKey('inline-correction')), findsNothing);
      expectWords(const ['Fui', 'a', 'la', 'tienda', 'ayer']);
      expect(find.text('I went to the shop yesterday.'), findsOneWidget);
      expect(find.text('I goed to the shop yesterday.'), findsNothing);
    },
  );

  testWidgets('third-language author keeps exact original in bottom lane', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AsyncData(
          result(
            learning: 'Was machst du?',
            interfaceText: 'What are you doing?',
            source: 'uk',
          ),
        ),
        authoredText: 'Що ти робиш?',
        isOutgoing: true,
      ),
    );

    expectWords(const ['Was', 'machst', 'du']);
    expect(find.text('Що ти робиш?'), findsOneWidget);
    expect(find.text('What are you doing?'), findsNothing);
  });

  testWidgets('third-language recipient gets their interface lane', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AsyncData(
          result(
            learning: 'Was machst du?',
            interfaceText: 'What are you doing?',
            source: 'es',
          ),
        ),
        authoredText: '¿Qué estás haciendo?',
      ),
    );

    expectWords(const ['Was', 'machst', 'du']);
    expect(find.text('What are you doing?'), findsOneWidget);
    expect(find.text('¿Qué estás haciendo?'), findsNothing);
  });

  testWidgets(
    'recipient keeps interface text when source is their interface language',
    (tester) async {
      await tester.pumpWidget(
        host(
          AsyncData(
            result(
              learning: 'Go to the link.',
              interfaceText: 'Перейди за посиланням.',
              source: 'uk',
              learningCode: 'en',
              interfaceCode: 'uk',
            ),
          ),
          authoredText: 'Перейди за посиланням.',
          learningCode: 'en',
          interfaceCode: 'uk',
        ),
      );

      expectWords(const ['Go', 'to', 'the', 'link']);
      expect(find.text('Перейди за посиланням.'), findsOneWidget);
    },
  );

  testWidgets('source-interface message uses normalized bottom lane', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AsyncData(
          result(
            learning: 'Was machst du?',
            interfaceText: 'What are you doing?',
            source: 'en',
          ),
        ),
        authoredText: 'What is you doing?',
        isOutgoing: true,
      ),
    );

    expectWords(const ['Was', 'machst', 'du']);
    expect(find.text('What are you doing?'), findsOneWidget);
    expect(find.text('What is you doing?'), findsNothing);
  });

  testWidgets('identical learning and interface output renders once', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AsyncData(
          result(
            learning: 'Was machst du?',
            interfaceText: 'Was machst du?',
            source: 'en',
            interfaceCode: 'de',
          ),
        ),
        interfaceCode: 'de',
      ),
    );

    expectWords(const ['Was', 'machst', 'du']);
  });

  testWidgets('short tokenized translations keep a readable minimum width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: IntrinsicWidth(
              child: MessageLearningContent(
                authoredText: 'hi',
                translation: AsyncData(
                  result(
                    learning: 'வா',
                    interfaceText: 'hi',
                    source: 'en',
                    learningCode: 'ta',
                  ),
                ),
                showTranslation: true,
                learningLanguageCode: 'ta',
                interfaceLanguageCode: 'en',
                isOutgoing: false,
                popupTopInset: 0,
                unavailableText: 'Translation unavailable',
                retryText: 'Retry',
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(MessageLearningContent)).width,
      greaterThanOrEqualTo(156),
    );
  });

  testWidgets('aid mode none renders only the exact original message', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AsyncData(
          result(
            learning: 'Was machst du?',
            interfaceText: 'What are you doing?',
            source: 'de',
            mode: LearningAidMode.none,
          ),
        ),
        authoredText: 'Was machst du?',
        isOutgoing: true,
      ),
    );

    expect(find.text('Was machst du?'), findsOneWidget);
    expect(find.text('What are you doing?'), findsNothing);
    expect(find.byKey(const ValueKey('translation-shimmer')), findsNothing);
    expect(find.textContaining('Correction:'), findsNothing);
  });

  testWidgets('disabled learning aids show only exact original', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AsyncData(
          result(
            learning: 'Was machst du?',
            interfaceText: 'What are you doing?',
            source: 'uk',
          ),
        ),
        authoredText: 'Що ти робиш?',
        showTranslation: false,
      ),
    );

    expect(find.text('Що ти робиш?'), findsOneWidget);
    expect(find.text('Was machst du?'), findsNothing);
  });

  testWidgets('unavailable state preserves original and exposes retry', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      host(
        AsyncError(Exception('offline'), StackTrace.empty),
        authoredText: 'Was machst du?',
        onRetry: () => retried = true,
      ),
    );

    expect(find.text('Translation unavailable'), findsOneWidget);
    expect(find.text('Was machst du?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('translation-retry')));
    expect(retried, isTrue);
  });
}
