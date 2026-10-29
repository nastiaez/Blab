import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/data/translation_support.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'all picker languages route to translation and an explicit speech locale',
    () {
      expect(
        kBlabLanguages.map((l) => l.code).toSet(),
        kSupportedLearningLanguages,
      );
      expect(kBlabLanguages.length, 16);
      for (final code in ['da', 'fi', 'ko', 'mr', 'pl']) {
        expect(TtsService.localeFor(code), isNotNull);
        expect(kSupportedInterfaceLanguageCodes.contains(code), isFalse);
        for (final locale in ['en', 'de', 'es', 'uk']) {
          final l10n = lookupAppLocalizations(Locale(locale));
          expect(
            localizedLanguageName(l10n, code),
            isNot(l10n.languageEnglish),
          );
          expect(
            l10n.learningTimelineMarker(code),
            isNot(l10n.learningTimelineMarker('en')),
          );
        }
      }
    },
  );
}
