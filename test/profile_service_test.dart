import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/models/reading_script.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserProfile.fromRow maps known_languages and primary_known_language '
      'from a row', () {
    final profile = UserProfile.fromRow({
      'display_name': 'Nastia',
      'interface_language': 'en',
      'known_languages': ['en', 'uk'],
      'primary_known_language': 'en',
    });

    expect(profile.knownLanguages, ['en', 'uk']);
    expect(profile.primaryKnownLanguage, 'en');
  });

  test('UserProfile.fromRow defaults known_languages to empty and primary to '
      'null when absent', () {
    final profile = UserProfile.fromRow({
      'display_name': 'Nastia',
      'interface_language': 'en',
    });

    expect(profile.knownLanguages, isEmpty);
    expect(profile.primaryKnownLanguage, isNull);
    expect(profile.readingScript, ReadingScript.native);
  });

  test('UserProfile.fromRow maps the saved reading script', () {
    final profile = UserProfile.fromRow({
      'display_name': 'Nastia',
      'interface_language': 'en',
      'reading_script': 'english_letters',
    });

    expect(profile.readingScript, ReadingScript.englishLetters);
  });
}
