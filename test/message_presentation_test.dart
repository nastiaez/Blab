import 'package:blab/features/chat/message_presentation.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/models/reading_script.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

MessageTranslation _translation({
  String translation = 'Привіт',
  String interfaceText = 'Hello',
  String sourceLang = 'en',
  LearningAidMode mode = LearningAidMode.translation,
  List<MessageToken> tokens = const [],
}) => MessageTranslation(
  translation: translation,
  interfaceText: interfaceText,
  interfaceLang: 'en',
  sourceLang: sourceLang,
  tokens: tokens,
  mode: mode,
);

void main() {
  test('pending preparation is delayed, not a terminal error', () {
    final result = resolveMessagePresentation(
      authoredText: 'Hello',
      translation: AsyncError(
        const MessageTranslationPending(),
        StackTrace.current,
      ),
      mode: ChatMode.practice,
      knownLanguageCodes: ['en'],
    );
    expect(result.translationFailed, false);
    expect(result.translationDelayed, true);
    expect(result.primaryText, 'Hello');
  });

  test(
    'practice primary text is learning language with known-language reveal',
    () {
      final result = resolveMessagePresentation(
        authoredText: 'Hello',
        translation: AsyncData(_translation()),
        mode: ChatMode.practice,
        knownLanguageCodes: const ['en'],
      );

      expect(result.primaryText, 'Привіт');
      expect(result.knownLanguageText, 'Hello');
      expect(result.listenText, 'Привіт');
      expect(result.canRevealOriginal, isFalse);
    },
  );

  test(
    'correct learning-language text retains known-language reveal and audio',
    () {
      final result = resolveMessagePresentation(
        authoredText: "Los geht's!",
        translation: AsyncData(
          _translation(
            translation: "Los geht's!",
            interfaceText: "Let's go!",
            sourceLang: 'de',
            mode: LearningAidMode.none,
          ),
        ),
        mode: ChatMode.practice,
        knownLanguageCodes: const ['en'],
        targetLanguageCode: 'de',
      );
      expect(result.primaryText, "Los geht's!");
      expect(result.knownLanguageText, "Let's go!");
      expect(result.listenText, "Los geht's!");
    },
  );

  test('normal translated text exposes exact authored original', () {
    final result = resolveMessagePresentation(
      authoredText: 'Hola',
      translation: AsyncData(
        _translation(translation: 'Hello', sourceLang: 'es'),
      ),
      mode: ChatMode.normal,
      knownLanguageCodes: const ['en'],
    );

    expect(result.primaryText, 'Hello');
    expect(result.originalText, 'Hola');
    expect(result.canRevealOriginal, isTrue);
    expect(result.listenText, isNull);
  });

  test('normal known source stays authored and has no Original action', () {
    final result = resolveMessagePresentation(
      authoredText: 'Hola',
      translation: AsyncData(
        _translation(translation: 'Hello', sourceLang: 'es'),
      ),
      mode: ChatMode.normal,
      knownLanguageCodes: const ['en', 'es'],
    );

    expect(result.primaryText, 'Hola');
    expect(result.canRevealOriginal, isFalse);
  });

  test('unsupported source keeps original and disables learning actions', () {
    final result = resolveMessagePresentation(
      authoredText: '你好',
      translation: AsyncData(
        _translation(translation: 'Hallo', sourceLang: 'other'),
      ),
      mode: ChatMode.practice,
      knownLanguageCodes: const ['uk'],
    );

    expect(result.primaryText, '你好');
    expect(result.unsupportedSource, isTrue);
    expect(result.canRevealOriginal, isFalse);
    expect(result.listenText, isNull);
    expect(result.knownLanguageText, isNull);
  });

  test('stylized supported text still uses the translated learning line', () {
    final result = resolveMessagePresentation(
      authoredText: 'Heeeeeeey!',
      translation: AsyncData(
        _translation(translation: 'Привіііііт!', sourceLang: 'other'),
      ),
      mode: ChatMode.practice,
      knownLanguageCodes: const ['uk'],
    );

    expect(result.primaryText, 'Привіііііт!');
    expect(result.unsupportedSource, isFalse);
    expect(result.listenText, 'Привіііііт!');
  });

  test('presentation applies English letters only to generated Hindi text', () {
    final result = resolveMessagePresentation(
      authoredText: 'Hello',
      translation: AsyncData(
        _translation(
          translation: 'नमस्ते',
          tokens: const [
            MessageToken(
              text: 'नमस्ते',
              romanization: 'namaste',
              gloss: 'hello',
            ),
          ],
        ),
      ),
      mode: ChatMode.practice,
      knownLanguageCodes: const ['en'],
      targetLanguageCode: 'hi',
      readingScript: ReadingScript.englishLetters,
    );

    expect(result.primaryText, 'namaste');
    expect(result.originalText, 'Hello');
    expect(result.listenText, 'नमस्ते');
  });

  test('aid mode none preserves authored native script', () {
    final result = resolveMessagePresentation(
      authoredText: 'नमस्ते',
      translation: AsyncData(
        _translation(
          translation: 'namaste',
          sourceLang: 'hi',
          mode: LearningAidMode.none,
        ),
      ),
      mode: ChatMode.practice,
      knownLanguageCodes: const ['en'],
      targetLanguageCode: 'hi',
      readingScript: ReadingScript.englishLetters,
    );

    expect(result.primaryText, 'नमस्ते');
  });
}
