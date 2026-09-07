import 'package:blab/features/chat/message_translation_lifecycle.dart';
import 'package:blab/shared/data/translation_support.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('containsMeaningBearingText', () {
    test('protected-only messages skip language processing', () {
      for (final text in <String>[
        '😊 ❤️',
        'https://blab.test/hello',
        '@alice',
        '#language_exchange',
        '`const greeting = "hi";`',
        '123 45.6',
        '8pm',
      ]) {
        expect(containsMeaningBearingText(text), isFalse, reason: text);
      }
    });

    test('CJK text remains eligible for source-language detection', () {
      expect(containsMeaningBearingText('你好'), isTrue);
      expect(containsMeaningBearingText('こんにちは'), isTrue);
    });

    test('mixed messages and chat abbreviations remain eligible', () {
      for (final text in <String>[
        'See you at 8pm 😊',
        'Ask @alice tomorrow',
        'Read https://blab.test later',
        'brb',
        'ttyl 👋',
      ]) {
        expect(containsMeaningBearingText(text), isTrue, reason: text);
      }
    });
  });

  test('stylized supported chat text is not treated as unsupported', () {
    expect(isExpressiveLanguageVariant('Heeeeeeey!'), isTrue);
    expect(isExpressiveLanguageVariant('HelLoooooou?'), isTrue);
    expect(isExpressiveLanguageVariant('Palllaaaaviiiiiii?'), isTrue);
    expect(isExpressiveLanguageVariant('OMG'), isTrue);
    expect(isExpressiveLanguageVariant('你好'), isFalse);
    expect(
      isUnsupportedSourceText(sourceLang: 'other', authoredText: 'Heeeeeeey!'),
      isFalse,
    );
    expect(
      isUnsupportedSourceText(sourceLang: 'other', authoredText: '你好'),
      isTrue,
    );
  });

  test('speed boundaries select fast medium and slow branches', () {
    expect(
      translationSpeedBranch(const Duration(milliseconds: 179)),
      TranslationSpeedBranch.fast,
    );
    expect(
      translationSpeedBranch(const Duration(milliseconds: 180)),
      TranslationSpeedBranch.medium,
    );
    expect(
      translationSpeedBranch(const Duration(milliseconds: 349)),
      TranslationSpeedBranch.medium,
    );
    expect(
      translationSpeedBranch(const Duration(milliseconds: 350)),
      TranslationSpeedBranch.slow,
    );
  });

  test('incoming content is held only while its first result is pending', () {
    expect(
      shouldHoldIncomingTranslation(
        isOutgoing: false,
        processing: true,
        originalWasRevealedAfterFailure: false,
      ),
      isTrue,
    );
    expect(
      shouldHoldIncomingTranslation(
        isOutgoing: false,
        processing: true,
        originalWasRevealedAfterFailure: true,
      ),
      isFalse,
    );
    expect(
      shouldHoldIncomingTranslation(
        isOutgoing: true,
        processing: true,
        originalWasRevealedAfterFailure: false,
      ),
      isFalse,
    );
  });

  test('no-change result keeps the exact authored line', () {
    MessageTranslation result({
      required String text,
      LearningAidMode mode = LearningAidMode.translation,
    }) => MessageTranslation(
      translation: text,
      interfaceText: text,
      interfaceLang: 'en',
      sourceLang: 'en',
      tokens: const [],
      mode: mode,
    );

    expect(
      translationResultIsUnchanged('Hello', result(text: 'Hello')),
      isTrue,
    );
    expect(
      translationResultIsUnchanged(
        'Hello',
        result(text: 'Hello', mode: LearningAidMode.correction),
      ),
      isFalse,
    );
    expect(
      translationResultIsUnchanged('Hello', result(text: 'Hallo')),
      isFalse,
    );
  });
}
