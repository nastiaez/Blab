import 'package:blab/shared/services/tts_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TtsService.localeFor', () {
    test('maps each Blab language code to its BCP-47 locale', () {
      expect(TtsService.localeFor('ta'), 'ta-IN');
      expect(TtsService.localeFor('uk'), 'uk-UA');
      expect(TtsService.localeFor('es'), 'es-ES');
      expect(TtsService.localeFor('de'), 'de-DE');
      expect(TtsService.localeFor('hi'), 'hi-IN');
      expect(TtsService.localeFor('it'), 'it-IT');
      expect(TtsService.localeFor('pt'), 'pt-PT');
      expect(TtsService.localeFor('nl'), 'nl-NL');
      expect(TtsService.localeFor('fr'), 'fr-FR');
      expect(TtsService.localeFor('tr'), 'tr-TR');
      expect(TtsService.localeFor('en'), 'en-US');
    });

    test('returns null for unknown codes', () {
      expect(TtsService.localeFor('xx'), isNull);
      expect(TtsService.localeFor(''), isNull);
    });

    test('covers all 11 supported languages', () {
      expect(TtsService.kLocaleByCode.length, 11);
    });
  });
}
