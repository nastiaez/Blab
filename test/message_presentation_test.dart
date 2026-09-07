import 'package:blab/features/chat/message_presentation.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

MessageTranslation _translation({
  String translation = 'Привіт',
  String interfaceText = 'Hello',
  String sourceLang = 'en',
  LearningAidMode mode = LearningAidMode.translation,
}) => MessageTranslation(
  translation: translation,
  interfaceText: interfaceText,
  interfaceLang: 'en',
  sourceLang: sourceLang,
  tokens: const [],
  mode: mode,
);

void main() {
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
}
