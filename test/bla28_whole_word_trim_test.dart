import 'package:flutter_test/flutter_test.dart';
import 'package:blab/features/chat/widgets/inline_correction_text.dart';

void main() {
  List<CorrectionSegment> render(
    String original,
    String replacement, {
    String? target,
    String? anchor,
    String before = '',
    String after = '',
  }) {
    final source = before + original + after;
    final output = target ?? before + replacement + after;
    final a = anchor ?? replacement;
    final start = output.indexOf(a);
    return translatedCorrectionSegments(source, output, {
      'version': 'a-v2',
      'source': source,
      'targetText': output,
      'correctionText': before + replacement + after,
      'corrections': [
        {
          'original': original,
          'replacement': replacement,
          'start': before.length,
          'end': before.length + original.length,
          'occurrence': 0,
          'targetAnchor': {
            'text': a,
            'occurrence': 0,
            'start': start,
            'end': start + a.length,
          },
        },
      ],
    });
  }

  test(
    'independent exact edges do not trim morphology, case, punctuation or apostrophe',
    () {
      for (final row in [
        ['Ich ist', 'Ich bin', 'ist', 'bin'],
        ['ist hier', 'bin hier', 'ist', 'bin'],
        ['Ich ist hier', 'Ich bin hier', 'ist', 'bin'],
        ['der Mann', 'die Mann', 'der', 'die'],
        ['unhappy', 'unfair', 'unhappy', 'unfair'],
        ['bist', 'ist', 'bist', 'ist'],
        ['foo-bar', 'foo-baz', 'foo-bar', 'foo-baz'],
        ['can’t', 'can', 'can’t', 'can'],
        ['Ich ist', 'ich bin', 'Ich ist', 'ich bin'],
      ]) {
        final result = render(row[0], row[1]);
        expect(result.where((s) => s.struck).map((s) => s.text).toList(), [
          row[2],
        ]);
        expect(result.where((s) => s.corrected).map((s) => s.text).toList(), [
          row[3],
        ]);
        expect(
          result.where((s) => !s.struck).map((s) => s.text).join(),
          row[1],
        );
      }
    },
  );
  test(
    'retain real correction on reordered/nonmatching target; unicode/protected boundaries',
    () {
      for (final target in ['you are', 'hier bist du']) {
        final result = render(
          'Ich ist',
          'Ich bin',
          target: target,
          anchor: target,
        );
        expect(result.where((s) => s.struck).single.text, 'Ich ist');
        expect(
          result.where((s) => !s.struck).map((s) => s.text).join(),
          target,
        );
      }
      final emoji = render('Ich ist hier', 'Ich bin hier', before: '😀 ');
      expect(emoji.where((s) => s.struck).single.text, 'ist');
      expect(
        emoji.where((s) => !s.struck).map((s) => s.text).join(),
        '😀 Ich bin hier',
      );
      final protected = render('@Alice ist', '@Alice bin');
      expect(protected.where((s) => s.struck), isEmpty);
    },
  );
  test('original target overlap remains rejected after shrinking', () {
    final segments = translatedCorrectionSegments('A ist X', 'A bin', {
      'version': 'a-v2',
      'source': 'A ist X',
      'targetText': 'A bin',
      'correctionText': 'A bin A',
      'corrections': [
        {
          'original': 'A ist',
          'replacement': 'A bin',
          'start': 0,
          'end': 5,
          'occurrence': 0,
          'targetAnchor': {
            'text': 'A bin',
            'start': 0,
            'end': 5,
            'occurrence': 0,
          },
        },
        {
          'original': 'X',
          'replacement': 'A',
          'start': 6,
          'end': 7,
          'occurrence': 0,
          'targetAnchor': {'text': 'A', 'start': 0, 'end': 1, 'occurrence': 0},
        },
      ],
    });
    expect(segments.where((s) => s.struck), isEmpty);
    expect(segments.single.text, 'A bin');
  });
}
