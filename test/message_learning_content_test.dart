import 'package:blab/features/chat/widgets/inline_correction_text.dart';
import 'package:blab/features/chat/widgets/message_learning_content.dart';
import 'package:blab/features/chat/widgets/message_text.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/models/grammatical_form.dart';
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
    // Defaults reproduce the pre-mode always-dual-lane behavior so existing
    // fixtures below don't all need touching: practice mode, expanded.
    // Tests exercising the new mode-based branching pass these explicitly.
    ChatMode mode = ChatMode.practice,
    List<String> knownLanguageCodes = const [],
    String? resolvedSourceLang,
    bool expanded = true,
    VoidCallback? onToggleExpanded,
    VoidCallback? onRetry,
    GrammaticalForm? resolvedForm,
    GrammaticalFormAlternatives? formAlternativesOverride,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MessageLearningContent(
          authoredText: authoredText,
          translation: translation,
          showTranslation: showTranslation,
          learningLanguageCode: learningCode,
          isOutgoing: isOutgoing,
          popupTopInset: 0,
          unavailableText: 'Translation unavailable',
          retryText: 'Retry',
          onRetry: onRetry,
          resolvedForm: resolvedForm,
          formAlternativesOverride: formAlternativesOverride,
          mode: mode,
          knownLanguageCodes: knownLanguageCodes,
          resolvedSourceLang: resolvedSourceLang,
          expanded: expanded,
          onToggleExpanded: onToggleExpanded ?? () {},
        ),
      ),
    );
  }

  void expectWords(Iterable<String> words) {
    for (final word in words) {
      expect(find.text(word), findsOneWidget);
    }
  }

  testWidgets('unsupported source keeps the authored text visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AsyncData(
          result(learning: 'Hallo', interfaceText: 'Hello', source: 'other'),
        ),
        authoredText: '你好',
        mode: ChatMode.practice,
        learningCode: 'de',
      ),
    );

    expect(find.text('你好'), findsOneWidget);
    expect(find.text('Hallo'), findsNothing);
  });

  testWidgets('stylized source still shows its translated learning line', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AsyncData(
          result(
            learning: 'Привіііііт!',
            interfaceText: 'Hi!',
            source: 'other',
          ),
        ),
        authoredText: 'Heeeeeeey!',
        mode: ChatMode.practice,
        learningCode: 'uk',
      ),
    );

    expect(find.byType(MessageText), findsOneWidget);
    expect(find.text('Heeeeeeey!'), findsNothing);
  });

  test(
    'inline correction keeps cosmetic edits clean and strikes replacement',
    () {
      expect(
        correctionSegments('was machen du', 'Was machst du?')
            .map((segment) => (segment.text, segment.struck, segment.corrected))
            .toList(),
        [
          ('Was ', false, false),
          ('machen', true, false),
          (' ', false, false),
          ('machst', false, true),
          (' du', false, false),
          ('?', false, true),
        ],
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

  testWidgets('short tokenized translations keep their intrinsic width', (
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
                isOutgoing: false,
                popupTopInset: 0,
                unavailableText: 'Translation unavailable',
                retryText: 'Retry',
                mode: ChatMode.practice,
                knownLanguageCodes: const [],
                expanded: false,
                onToggleExpanded: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(MessageLearningContent)).width,
      lessThan(156),
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

  testWidgets('unavailable state preserves original without inline chrome', (
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

    expect(find.text('Translation unavailable'), findsNothing);
    expect(find.text('Was machst du?'), findsOneWidget);
    expect(find.byKey(const ValueKey('translation-retry')), findsNothing);
    expect(retried, isFalse);
  });

  // Mode-display-fixes spec § 1: one lane while loading, in both modes. The
  // authored text is readable throughout and the swap to the learning
  // language is the completion signal — no shimmer, no second lane.

  testWidgets('practice mode shows a single plain lane while loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const AsyncLoading(), authoredText: 'Was machst du?'),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('translation-shimmer')), findsNothing);
    expect(find.text('Was machst du?'), findsOneWidget);
  });

  testWidgets('normal mode shows a single plain lane while loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AsyncLoading(),
        authoredText: 'Was machst du?',
        mode: ChatMode.normal,
        knownLanguageCodes: const ['en'],
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('translation-shimmer')), findsNothing);
    expect(find.text('Was machst du?'), findsOneWidget);
  });

  // Mode-display-fixes spec § 3 (client-side): normal-mode failure chrome
  // only where the reader positively cannot read the message on their own.

  testWidgets('normal mode keeps failure chrome outside message content', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      host(
        AsyncError(Exception('offline'), StackTrace.empty),
        authoredText: 'Was machst du?',
        mode: ChatMode.normal,
        knownLanguageCodes: const ['en'],
        resolvedSourceLang: 'de',
        onRetry: () => retried = true,
      ),
    );

    expect(find.text('Translation unavailable'), findsNothing);
    expect(find.text('Was machst du?'), findsOneWidget);
    expect(find.byKey(const ValueKey('translation-retry')), findsNothing);
    expect(retried, isFalse);
  });

  testWidgets(
    'normal mode stays silent on failure when the reader already knows the '
    'source language',
    (tester) async {
      await tester.pumpWidget(
        host(
          AsyncError(Exception('offline'), StackTrace.empty),
          authoredText: 'What are you doing?',
          mode: ChatMode.normal,
          knownLanguageCodes: const ['en', 'uk'],
          resolvedSourceLang: 'en',
          onRetry: () {},
        ),
      );

      expect(find.text('What are you doing?'), findsOneWidget);
      expect(find.text('Translation unavailable'), findsNothing);
      expect(find.byKey(const ValueKey('translation-retry')), findsNothing);
    },
  );

  testWidgets(
    'normal mode stays silent on failure when the source language was never '
    'resolved (background auto-retry recovers it)',
    (tester) async {
      await tester.pumpWidget(
        host(
          AsyncError(Exception('offline'), StackTrace.empty),
          authoredText: 'Was machst du?',
          mode: ChatMode.normal,
          knownLanguageCodes: const ['en'],
          onRetry: () {},
        ),
      );

      expect(find.text('Was machst du?'), findsOneWidget);
      expect(find.text('Translation unavailable'), findsNothing);
      expect(find.byKey(const ValueKey('translation-retry')), findsNothing);
    },
  );

  testWidgets('practice failure keeps authored content free of inline chrome', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      host(
        AsyncError(Exception('offline'), StackTrace.empty),
        authoredText: 'What are you doing?',
        mode: ChatMode.practice,
        knownLanguageCodes: const ['en'],
        resolvedSourceLang: 'en',
        onRetry: () => retried = true,
      ),
    );

    expect(find.text('What are you doing?'), findsOneWidget);
    expect(find.text('Translation unavailable'), findsNothing);
    expect(find.byKey(const ValueKey('translation-retry')), findsNothing);
    expect(retried, isFalse);
  });

  // Mode-display-fixes spec § 2: identical content, identical height in
  // both modes — practice mode's per-word tap targets must not inflate the
  // line box.

  testWidgets('the same message is the same height in both modes', (
    tester,
  ) async {
    const authored = 'What are you doing this evening, and where?';
    const learning = 'Was machst du heute Abend, und wo?';

    Future<double> heightIn(ChatMode mode) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 220,
                child: MessageLearningContent(
                  authoredText: authored,
                  translation: AsyncData(
                    result(
                      learning: learning,
                      interfaceText: authored,
                      source: 'en',
                    ),
                  ),
                  showTranslation: true,
                  learningLanguageCode: 'de',
                  isOutgoing: false,
                  popupTopInset: 0,
                  unavailableText: 'Translation unavailable',
                  retryText: 'Retry',
                  mode: mode,
                  knownLanguageCodes: const [],
                  expanded: false,
                  onToggleExpanded: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getSize(find.byType(MessageLearningContent).first).height;
    }

    // Both modes render the same string — normal mode as a plain line
    // (unknown source → the translation), practice mode as tappable words.
    final practiceHeight = await heightIn(ChatMode.practice);
    final normalHeight = await heightIn(ChatMode.normal);

    expect(practiceHeight, normalHeight);
  });

  // FR-23: single-lane default + known-language bypass.

  testWidgets('masculine visible form uses masculine word metadata', (
    tester,
  ) async {
    final translated = await MessageTranslator(
      invoke: ({required messageId}) async => {
        'translation': 'Я прийшла.',
        'interfaceText': 'I arrived.',
        'interfaceLang': 'en',
        'sourceLang': 'en',
        'mode': 'translation',
        'explanation': null,
        'confidence': null,
        'tokens': [
          {'text': 'Я', 'gloss': 'I', 'roman': 'Ya', 'isContent': true},
          {'text': ' ', 'gloss': null, 'roman': null, 'isContent': false},
          {
            'text': 'прийшла',
            'gloss': 'arrived',
            'roman': 'pryishla',
            'isContent': true,
          },
          {'text': '.', 'gloss': null, 'roman': null, 'isContent': false},
        ],
        'formAlternatives': {
          'before': '',
          'feminine': 'Я прийшла',
          'masculine': 'Я прийшов',
          'after': '.',
          'subjectName': 'Bob',
          'subjectIsViewer': true,
          'subjectRole': 'author',
          'suggestedForm': 'feminine',
          'feminineTokens': [
            {'text': 'Я', 'gloss': 'I', 'roman': 'Ya', 'isContent': true},
            {'text': ' ', 'gloss': null, 'roman': null, 'isContent': false},
            {
              'text': 'прийшла',
              'gloss': 'arrived',
              'roman': 'pryishla',
              'isContent': true,
            },
            {'text': '.', 'gloss': null, 'roman': null, 'isContent': false},
          ],
          'masculineTokens': [
            {'text': 'Я', 'gloss': 'I', 'roman': 'Ya', 'isContent': true},
            {'text': ' ', 'gloss': null, 'roman': null, 'isContent': false},
            {
              'text': 'прийшов',
              'gloss': 'arrived',
              'roman': 'pryishov',
              'isContent': true,
            },
            {'text': '.', 'gloss': null, 'roman': null, 'isContent': false},
          ],
        },
      },
    ).translate(messageId: 'message-1');

    await tester.pumpWidget(
      host(
        AsyncData(translated),
        authoredText: 'I arrived.',
        mode: ChatMode.practice,
        learningCode: 'uk',
        resolvedForm: GrammaticalForm.masculine,
        expanded: false,
      ),
    );

    final line = tester.widget<MessageText>(find.byType(MessageText));
    expect(line.text, 'Я прийшов.');
    expect(
      line.tokens
          ?.map(
            (token) =>
                (token.text, token.gloss, token.romanization, token.isContent),
          )
          .toList(),
      [
        ('Я', 'I', 'Ya', true),
        (' ', null, null, false),
        ('прийшов', 'arrived', 'pryishov', true),
        ('.', null, null, false),
      ],
    );
  });

  testWidgets('normal mode, known source language shows original only', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AsyncData(
          result(learning: 'Привіт', interfaceText: 'Hi', source: 'uk'),
        ),
        authoredText: 'Привіт',
        mode: ChatMode.normal,
        knownLanguageCodes: const ['en', 'uk'],
        expanded: false,
      ),
    );

    expect(find.text('Привіт'), findsOneWidget);
    expect(find.text('Hi'), findsNothing);
  });

  testWidgets(
    'normal known source keeps exact authored text despite form alternatives',
    (tester) async {
      const alternatives = GrammaticalFormAlternatives(
        before: 'Ти ',
        feminine: 'ходила',
        masculine: 'ходив',
        after: '?',
        subjectName: 'Bob',
        subjectIsViewer: true,
        subjectRole: 'recipient',
      );
      const authored = 'Did YOU go...?';
      await tester.pumpWidget(
        host(
          const AsyncData(
            MessageTranslation(
              translation: 'Ти ходила?',
              interfaceText: authored,
              interfaceLang: 'en',
              sourceLang: 'en',
              tokens: [],
              formAlternatives: alternatives,
            ),
          ),
          authoredText: authored,
          mode: ChatMode.normal,
          knownLanguageCodes: const ['en'],
          resolvedForm: GrammaticalForm.masculine,
          expanded: false,
        ),
      );

      expect(find.text(authored), findsOneWidget);
      expect(find.text('Ти ходив?'), findsNothing);
    },
  );

  testWidgets(
    'normal mode, unknown source language shows the translation, no second lane',
    (tester) async {
      await tester.pumpWidget(
        host(
          AsyncData(result(learning: 'Hi', interfaceText: 'Hi', source: 'pl')),
          authoredText: 'Cześć',
          mode: ChatMode.normal,
          knownLanguageCodes: const ['en'],
          expanded: false,
        ),
      );

      expect(find.text('Hi'), findsOneWidget);
      // Original not shown by default in the normal-mode-unknown case.
      expect(find.text('Cześć'), findsNothing);
    },
  );

  testWidgets(
    'practice mode, not expanded, shows only the learning-language line',
    (tester) async {
      await tester.pumpWidget(
        host(
          AsyncData(
            result(learning: 'hallo', interfaceText: 'hello', source: 'en'),
          ),
          authoredText: 'hello',
          mode: ChatMode.practice,
          knownLanguageCodes: const ['en'],
          expanded: false,
        ),
      );

      expect(find.text('hallo'), findsOneWidget);
      // Second lane not shown until expanded.
      expect(find.text('hello'), findsNothing);
    },
  );

  testWidgets('practice mode, expanded, shows the second lane too', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AsyncData(
          result(learning: 'hallo', interfaceText: 'hello', source: 'en'),
        ),
        authoredText: 'hello',
        mode: ChatMode.practice,
        knownLanguageCodes: const ['en'],
        expanded: true,
      ),
    );

    expect(find.text('hallo'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
  });
}
