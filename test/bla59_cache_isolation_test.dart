import 'package:blab/shared/services/deep_dive_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'corrected span does not reuse shifted span or other viewer/language',
    () async {
      const text =
          'Ich denke nach 16 Uhr. Was denkst du? Passt die Uhrzeit für dich?';
      var viewer = 'alice';
      final requests = <Map<String, dynamic>>[];
      final service = DeepDiveService(
        viewerId: () => viewer,
        invoke: (request) async {
          requests.add(request);
          return {'meaning': 'fixture-${requests.length}'};
        },
      );
      final start = text.indexOf('Uhrzeit');
      Future<Map<String, dynamic>> lookup(int offset, {String known = 'en'}) =>
          service.lookup(
            messageId: 'bla59',
            kind: 'word',
            text: text,
            start: offset,
            end: offset + 7,
            targetLang: 'de',
            knownLang: known,
            aidsEnabled: true,
            acceptedText: text,
            sourceText:
                'I’m denke nach 16 Uhr. Was denkst du? Passt die Uhr für dich?',
          );
      final shifted = await lookup(start + 2);
      expect(shifted['text'], 'rzeit f');
      final correct = await lookup(start);
      expect(correct['text'], 'Uhrzeit');
      expect(requests, hasLength(2));
      expect(await lookup(start), correct);
      expect(requests, hasLength(2));
      viewer = 'bob';
      expect((await lookup(start))['text'], 'Uhrzeit');
      expect(requests, hasLength(3));
      await lookup(start, known: 'uk');
      expect(requests, hasLength(4));
      viewer = 'alice';
      expect(await lookup(start), correct);
      expect(requests, hasLength(4));
      service.close();
    },
  );
}
