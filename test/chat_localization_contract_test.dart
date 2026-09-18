import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _catalog(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('every chat failure and recovery state is translated', () {
    final english = _catalog('en');
    const keys = <String>[
      'couldNotLoadMessages',
      'translationUnavailable',
      'couldntTranslateRetry',
      'couldntCheckRetry',
      'failedToSend',
      'messageFailed',
      'couldNotReport',
      'couldNotSaveLearningLanguage',
      'couldNotEditMessage',
      'couldNotBlock',
      'couldNotUnblock',
      'photoAccessNeeded',
      'photoAccessNeededBody',
      'noPhotosFound',
      'couldNotOpenPhotos',
      'couldNotSavePreference',
    ];

    for (final locale in const ['de', 'es', 'uk']) {
      final localized = _catalog(locale);
      for (final key in keys) {
        expect(
          localized[key],
          isA<String>(),
          reason: '$locale is missing $key',
        );
        expect(
          localized[key],
          isNot(equals(english[key])),
          reason: '$locale still falls back to English for $key',
        );
      }
    }
  });

  test('chat errors and actions use informal Ukrainian singular copy', () {
    final ukrainian = _catalog('uk');

    expect(ukrainian['learningLanguageHelp'], contains('Вибери'));
    expect(
      ukrainian['practiceComposerHint'],
      'Пиши: {learningLanguage} або {knownLanguage}',
    );
    expect(ukrainian['failedToSend'], contains('Натисни'));
    expect(ukrainian['sayHi'], 'Привітайся');
    expect(
      ukrainian['deleteMessageBody'],
      'Це повідомлення також буде видалено для {name}.',
    );
    expect(ukrainian['couldNotReport'], endsWith('Спробуй ще раз.'));
    expect(
      ukrainian['couldNotSaveLearningLanguage'],
      endsWith('Спробуй ще раз.'),
    );
    expect(ukrainian['couldNotEditMessage'], endsWith('Спробуй ще раз.'));
    expect(ukrainian['couldNotBlock'], endsWith('Спробуй ще раз.'));
    expect(ukrainian['couldNotUnblock'], endsWith('Спробуй ще раз.'));
    expect(ukrainian['photoAccessNeededBody'], startsWith('Дозволь '));
    expect(ukrainian['you'], 'Ти');
  });

  test('chat UI sources do not bypass localization', () {
    const forbiddenByFile = {
      'lib/features/chat/chat_screen.dart': [
        'Could not open photos. Try again.',
        'Translation preferences',
        'Now learning ',
        ' new message',
        'Practice mode',
        'Normal mode',
        'Messages appear in ',
        'Messages in languages you know',
        'Edit known languages',
      ],
      'lib/features/chat/widgets/learning_language_sheet.dart': [
        'Start practicing',
        'Choose a language to practice',
        'You can change it later in Settings.',
        'language.name',
      ],
      'lib/features/chat/widgets/grammatical_form_chooser.dart': [
        'Choose grammatical form',
        'gendered form',
        'Couldn’t save. Try again.',
      ],
      'lib/features/chat/translation_preferences_screen.dart': [
        'Couldn’t save. Try again.',
      ],
      'lib/features/chat/widgets/first_message_empty_state.dart': [
        'No messages here yet…',
        'Send any message to start.',
      ],
      'lib/features/chat/widgets/photo_preview_sheet.dart': [
        'Add a caption...',
      ],
      'lib/features/chat/widgets/gallery_picker_screen.dart': ["'Camera'"],
      'lib/features/chat/widgets/floating_reaction_row.dart': [
        'React with ',
        'More reactions',
      ],
    };

    for (final entry in forbiddenByFile.entries) {
      final source = File(entry.key).readAsStringSync();
      for (final english in entry.value) {
        expect(
          source,
          isNot(contains(english)),
          reason: '${entry.key} must localize "$english"',
        );
      }
    }
  });
}
