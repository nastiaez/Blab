import 'package:flutter_test/flutter_test.dart';
import 'package:blab/features/chat/widgets/inline_correction_text.dart';

void main() {
  test(
    'synthetic target anchors preserve whole translation and clean fallback',
    () {
      final metadata = <String, dynamic>{
        'version': 'a-v2',
        'source': 'Ich ist tired.',
        'correctionText': 'Ich bin tired.',
        'targetText': 'Ich bin müde.',
        'corrections': [
          <String, dynamic>{
            'original': 'ist',
            'replacement': 'bin',
            'occurrence': 0,
            'start': 4,
            'end': 7,
            'targetAnchor': {
              'text': 'bin',
              'occurrence': 0,
              'start': 4,
              'end': 7,
            },
          },
        ],
      };
      final segments = translatedCorrectionSegments(
        'Ich ist tired.',
        'Ich bin müde.',
        metadata,
      );
      expect(
        segments.where((s) => !s.struck).map((s) => s.text).join(),
        'Ich bin müde.',
      );
      expect(segments.where((s) => s.struck).single.text, 'ist');
      expect(segments.where((s) => s.corrected).single.text, 'bin');
      final row = (metadata['corrections'] as List).single as Map;
      for (final anchor in [
        null,
        {},
        {'text': 'bin', 'occurrence': 1, 'start': 4, 'end': 7},
        {'text': 'bin', 'occurrence': 0, 'start': 0, 'end': 3},
      ]) {
        row['targetAnchor'] = anchor;
        final clean = translatedCorrectionSegments(
          'Ich ist tired.',
          'Ich bin müde.',
          metadata,
        );
        expect(clean.single.text, 'Ich bin müde.');
        expect(clean.single.struck, false);
      }
    },
  );

  test(
    'synthetic repeat reorder multiword protected overlap and stale boundaries',
    () {
      Map<String, dynamic> fixture(
        String target,
        List<Map<String, dynamic>> corrections,
      ) => {
        'version': 'a-v2',
        'source': 'Ich ist tired; sie ist busy.',
        'correctionText': 'Ich bin tired; sie ist busy.',
        'targetText': target,
        'corrections': corrections,
      };
      Map<String, dynamic> correction(
        String text,
        int occurrence,
        int start,
        int end,
      ) => {
        'original': 'ist',
        'replacement': 'bin',
        'occurrence': 0,
        'start': 4,
        'end': 7,
        'targetAnchor': {
          'text': text,
          'occurrence': occurrence,
          'start': start,
          'end': end,
        },
      };
      for (final row in [
        ('bin, ich bin müde.', 'bin', 1, 9, 12),
        ('Müde bin ich.', 'bin', 0, 5, 8),
        ('I am very tired.', 'am very', 0, 2, 9),
      ]) {
        final target = row.$1;
        final result = translatedCorrectionSegments(
          'Ich ist tired; sie ist busy.',
          target,
          fixture(target, [correction(row.$2, row.$3, row.$4, row.$5)]),
        );
        expect(
          result.where((s) => !s.struck).map((s) => s.text).join(),
          target,
        );
        expect(result.where((s) => s.corrected).single.text, row.$2);
      }
      for (final row in [
        ('See https://example.org/bin', 'bin', 0, 24, 27),
        ('See @bin', 'bin', 0, 5, 8),
        ('See \x60bin\x60', 'bin', 0, 5, 8),
        ('Ich bin müde.', 'bin', -1, 4, 7),
        ('Ich bin müde.', 'bin', 9, 4, 7),
      ]) {
        final result = translatedCorrectionSegments(
          'Ich ist tired; sie ist busy.',
          row.$1,
          fixture(row.$1, [correction(row.$2, row.$3, row.$4, row.$5)]),
        );
        expect(result.single.text, row.$1);
        expect(result.single.struck, false);
      }
      final stale = fixture('Ich bin müde.', [correction('bin', 0, 4, 7)]);
      expect(
        translatedCorrectionSegments(
          'different source',
          'Ich bin müde.',
          stale,
        ).single.struck,
        false,
      );
      expect(
        translatedCorrectionSegments(
          'Ich ist tired; sie ist busy.',
          'Different output.',
          stale,
        ).single.text,
        'Different output.',
      );
    },
  );
}
