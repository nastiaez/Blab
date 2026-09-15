import 'package:blab/features/chat/reading_script_presentation.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/models/reading_script.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('presentReadingScript', () {
    test('presents a complete Tamil sentence in English letters', () {
      final result = presentReadingScript(
        text: 'வணக்கம், Maya! 😊',
        tokens: const [
          MessageToken(
            text: 'வணக்கம்',
            romanization: 'vanakkam',
            gloss: 'hello',
          ),
          MessageToken(text: ', ', isContent: false),
          MessageToken(text: 'Maya', gloss: 'Maya'),
          MessageToken(text: '! 😊', isContent: false),
        ],
        languageCode: 'ta',
        readingScript: ReadingScript.englishLetters,
      );

      expect(result.text, 'vanakkam, Maya! 😊');
      expect(result.usedEnglishLetters, isTrue);
      expect(result.tokens.first.text, 'vanakkam');
      expect(result.tokens.first.romanization, 'வணக்கம்');
      expect(result.tokens.first.nativeText, 'வணக்கம்');
      expect(result.tokens.first.gloss, 'hello');
      expect(result.tokens[2].text, 'Maya');
    });

    test('presents a complete Hindi sentence in English letters', () {
      final result = presentReadingScript(
        text: 'आप कैसे हैं?',
        tokens: const [
          MessageToken(text: 'आप', romanization: 'aap', gloss: 'you'),
          MessageToken(text: ' ', isContent: false),
          MessageToken(text: 'कैसे', romanization: 'kaise', gloss: 'how'),
          MessageToken(text: ' ', isContent: false),
          MessageToken(text: 'हैं', romanization: 'hain', gloss: 'are'),
          MessageToken(text: '?', isContent: false),
        ],
        languageCode: 'hi',
        readingScript: ReadingScript.englishLetters,
      );

      expect(result.text, 'aap kaise hain?');
      expect(result.usedEnglishLetters, isTrue);
      expect(
        result.tokens
            .where((token) => token.isContent)
            .map((token) => token.nativeText),
        ['आप', 'कैसे', 'हैं'],
      );
    });

    test('keeps the whole sentence native when romanization is incomplete', () {
      final tokens = const [
        MessageToken(text: 'आप', romanization: 'aap', gloss: 'you'),
        MessageToken(text: ' ', isContent: false),
        MessageToken(text: 'कैसे', gloss: 'how'),
      ];

      final result = presentReadingScript(
        text: 'आप कैसे',
        tokens: tokens,
        languageCode: 'hi',
        readingScript: ReadingScript.englishLetters,
      );

      expect(result.text, 'आप कैसे');
      expect(result.tokens, same(tokens));
      expect(result.usedEnglishLetters, isFalse);
    });

    test('does not transform native mode or an ineligible language', () {
      final tokens = const [
        MessageToken(text: 'नमस्ते', romanization: 'namaste'),
      ];

      final native = presentReadingScript(
        text: 'नमस्ते',
        tokens: tokens,
        languageCode: 'hi',
        readingScript: ReadingScript.native,
      );
      final ukrainian = presentReadingScript(
        text: 'नमस्ते',
        tokens: tokens,
        languageCode: 'uk',
        readingScript: ReadingScript.englishLetters,
      );

      expect(native.text, 'नमस्ते');
      expect(native.usedEnglishLetters, isFalse);
      expect(ukrainian.text, 'नमस्ते');
      expect(ukrainian.usedEnglishLetters, isFalse);
    });
  });
}
