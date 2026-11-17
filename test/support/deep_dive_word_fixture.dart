// Pure synthetic unit-test vocabulary. No users, credentials, backend or native runner.
import 'package:blab/shared/services/tts_service.dart';

class FixtureTts extends TtsService {
  bool failNext = false;
  @override
  Future<bool> isLanguageAvailable(String code) async =>
      !failNext && await super.isLanguageAvailable(code);
  @override
  Future<bool> speakWithStatus(String text, String code) async {
    if (failNext) {
      failNext = false;
      return false;
    }
    return super.speakWithStatus(text, code);
  }
}

Map<String, dynamic> word(String text, String gender) => {
  'text': text,
  'meaning': text == 'Bücher'
      ? 'books'
      : text == 'Busse'
      ? 'buses'
      : 'trains',
  'translation': text == 'Bücher'
      ? 'books'
      : text == 'Busse'
      ? 'buses'
      : 'trains',
  'gender': gender,
  'pronunciation': text == 'Bücher'
      ? '/ˈbyːçɐ/'
      : text == 'Busse'
      ? '/ˈbʊsə/'
      : '/ˈbaːnən/',
  'grammarLabel': 'Noun · G · pl'.replaceAll(
    'G',
    gender == 'neuter'
        ? 'n'
        : gender == 'masculine'
        ? 'm'
        : 'f',
  ),
  'explanation': text == 'Bücher'
      ? '“Zwei” means two, so use the plural. “Buch” adds -er and changes u to ü.'
      : text == 'Busse'
      ? '“Zwei” means two, so use the plural. “Bus” becomes “Busse”: double the s and add -e.'
      : '“Zwei” means two, so use the plural. “Bahn” adds -en to become “Bahnen”.',
  'whyThisForm': text == 'Bücher'
      ? '“Zwei” means two, so use the plural. “Buch” adds -er and changes u to ü.'
      : text == 'Busse'
      ? '“Zwei” means two, so use the plural. “Bus” becomes “Busse”: double the s and add -e.'
      : '“Zwei” means two, so use the plural. “Bahn” adds -en to become “Bahnen”.',
  'grammarHeaders': {'label': 'Number', 'value': 'Form'},
  'forms': [
    {
      'label': 'Singular',
      'form': text == 'Bücher'
          ? 'das Buch'
          : text == 'Busse'
          ? 'der Bus'
          : 'die Bahn',
    },
    {
      'label': 'Plural',
      'form': text == 'Bücher'
          ? 'die Bücher'
          : text == 'Busse'
          ? 'die Busse'
          : 'die Bahnen',
    },
  ],
  'examples': [
    {
      'text': text == 'Bücher'
          ? 'Ich lese zwei Bücher.'
          : 'Hier halten zwei $text.',
      'translation': text == 'Bücher'
          ? 'I’m reading two books.'
          : text == 'Busse'
          ? 'Two buses stop here.'
          : 'Two trains stop here.',
    },
    {
      'text': text == 'Bücher'
          ? 'Die Bücher liegen auf dem Tisch.'
          : text == 'Busse'
          ? 'Die Busse fahren zum Bahnhof.'
          : 'Die Bahnen fahren alle zehn Minuten.',
      'translation': text == 'Bücher'
          ? 'The books are on the table.'
          : text == 'Busse'
          ? 'The buses go to the station.'
          : 'The trains run every ten minutes.',
    },
  ],
};
