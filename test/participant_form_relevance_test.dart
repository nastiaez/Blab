import 'package:blab/shared/services/participant_form_relevance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = <(String, String, String, bool)>[
    ('de', 'Schreib deiner Mutter', 'Schreib deinem Mutter', false),
    ('de', 'Mit dieser App', 'Mit diesem App', false),
    ('de', 'Ich sehe meine Mutter.', 'Ich sehe meinen Mutter.', false),
    ('de', 'Das ist euer Buch.', 'Das ist eurem Buch.', false),
    ('de', 'Ich bin Lehrerin.', 'Ich bin Lehrer.', true),
    ('de', 'Sie ist meine Freundin.', 'Er ist mein Freund.', true),
    ('de', 'Das ist ihr Buch.', 'Das ist sein Buch.', true),
    ('de', 'Ich bin deine.', 'Ich bin deiner.', true),
    ('de', 'Du bist müde.', 'Du bist müde.', false),
    ('uk', 'Ти ходила вчора?', 'Ти ходив вчора?', true),
    ('es', 'Estoy cansada.', 'Estoy cansado.', true),
    ('fr', 'Je suis prête.', 'Je suis prêt.', true),
  ];
  for (final (language, feminine, masculine, expected) in cases) {
    test('$language: $feminine / $masculine', () {
      expect(
        hasParticipantFormDifference(
          targetLanguage: language,
          feminine: feminine,
          masculine: masculine,
        ),
        expected,
      );
    });
  }
}
