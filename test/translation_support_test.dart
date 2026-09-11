import 'package:blab/shared/data/translation_support.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveTranslationTarget', () {
    test('practice mode always targets the learning language', () {
      expect(
        resolveTranslationTarget(
          mode: ChatMode.practice,
          learningLanguageCode: 'de',
          primaryKnownLanguageCode: 'en',
        ),
        'de',
      );
    });

    test('normal mode targets the primary known language', () {
      expect(
        resolveTranslationTarget(
          mode: ChatMode.normal,
          learningLanguageCode: 'de',
          primaryKnownLanguageCode: 'en',
        ),
        'en',
      );
    });

    test('practice mode ignores the primary known language entirely', () {
      // Global constraint: practice mode has no known-language exception.
      expect(
        resolveTranslationTarget(
          mode: ChatMode.practice,
          learningLanguageCode: 'de',
          primaryKnownLanguageCode: 'de',
        ),
        'de',
      );
    });
  });

  group('shouldRequestTranslation', () {
    test('requests when target is supported and text is non-empty', () {
      expect(
        shouldRequestTranslation(
          targetLanguageCode: 'de',
          text: 'hallo',
          sentAt: DateTime(2026, 8, 11),
          translationCutoffAt: null,
        ),
        isTrue,
      );
    });

    test('does not request for an unsupported target code', () {
      expect(
        shouldRequestTranslation(
          targetLanguageCode: 'xx',
          text: 'hallo',
          sentAt: DateTime(2026, 8, 11),
          translationCutoffAt: null,
        ),
        isFalse,
      );
    });

    test('does not request for messages before the translation cutoff', () {
      expect(
        shouldRequestTranslation(
          targetLanguageCode: 'de',
          text: 'hallo',
          sentAt: DateTime(2026, 1, 1),
          translationCutoffAt: DateTime(2026, 6, 1),
        ),
        isFalse,
      );
    });

    test('does not request for blank text', () {
      expect(
        shouldRequestTranslation(
          targetLanguageCode: 'de',
          text: '   ',
          sentAt: DateTime(2026, 8, 11),
          translationCutoffAt: null,
        ),
        isFalse,
      );
    });
  });

  group('shouldRequestBubbleTranslation', () {
    test('mirrors shouldRequestTranslation', () {
      expect(
        shouldRequestBubbleTranslation(
          targetLanguageCode: 'en',
          text: 'Already English',
          sentAt: DateTime(2026, 8, 11),
          translationCutoffAt: null,
        ),
        isTrue,
      );
    });
  });
}
