import 'package:blab/features/chat/message_presentation.dart';
import 'package:blab/features/chat/widgets/inline_correction_text.dart';
import 'package:blab/features/chat/widgets/message_learning_content.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const source = '😀 Ich ist tired; sie ist busy.';
  final a = <String, dynamic>{
    'version': 'a-v1',
    'source': source,
    'correctionText': '😀 Ich bin tired; sie ist busy.',
    'corrections': [
      {'original': 'ist', 'replacement': 'bin', 'start': 7, 'end': 10},
    ],
  };
  test('A marks only explicit genuine error, never translated words', () {
    final rows = authoredCorrectionSegments(source, a);
    expect(rows.where((r) => r.struck).map((r) => r.text).toList(), ['ist']);
    expect(rows.where((r) => r.corrected).map((r) => r.text).toList(), ['bin']);
  });
  test('A repeated occurrence and multiple genuine errors remain distinct', () {
    const text = 'Ich ist und du ist; sie ist.';
    final rows = authoredCorrectionSegments(text, {
      'version': 'a-v1',
      'source': text,
      'correctionText': 'Ich bin und du bist; sie ist.',
      'corrections': [
        {'start': 4, 'end': 7, 'original': 'ist', 'replacement': 'bin'},
        {'start': 15, 'end': 18, 'original': 'ist', 'replacement': 'bist'},
      ],
    });
    expect(rows.where((r) => r.struck).length, 2);
    expect(
      rows.where((r) => !r.struck).map((r) => r.text).join(),
      'Ich bin und du bist; sie ist.',
    );
  });
  test('A rejects invalid overlap Unicode split and out-of-range spans', () {
    for (final raw in [
      [
        {'start': 0, 'end': 1, 'original': '\uD83D', 'replacement': 'x'},
      ],
      [
        {'start': -1, 'end': 3, 'original': 'Ich', 'replacement': 'x'},
      ],
      [
        {'start': 7, 'end': 100, 'original': 'ist', 'replacement': 'x'},
      ],
      [
        {'start': 7, 'end': 10, 'original': 'ist', 'replacement': 'bin'},
        {'start': 7, 'end': 10, 'original': 'ist', 'replacement': 'bin'},
      ],
    ]) {
      expect(
        authoredCorrectionSegments(source, {
          ...a,
          'corrections': raw,
        }).any((r) => r.struck || r.corrected),
        false,
      );
    }
    expect(authoredCorrectionSegments('other', a).single.text, 'other');
  });
  test(
    'new none Practice output preserved without changing legacy native behavior',
    () {
      for (final mode in ChatMode.values) {
        final value = MessageTranslation(
          translation: 'Ich bin müde.',
          interfaceText: 'I am tired.',
          interfaceLang: 'en',
          sourceLang: 'de',
          tokens: [],
          mode: LearningAidMode.none,
          authoredCorrection: a,
        );
        expect(
          resolveMessageDisplayText(
            authoredText: 'Ich bin tired.',
            value: value,
            mode: mode,
            knownLanguageCodes: ['de'],
            targetLanguageCode: 'de',
          ),
          mode == ChatMode.practice ? 'Ich bin müde.' : 'Ich bin tired.',
        );
      }
    },
  );
  test(
    'correction eligibility preserves independent viewer/send-time gates',
    () {
      for (final outgoing in [true, false]) {
        for (final matched in [true, false]) {
          for (final source in ['de', 'es']) {
            for (final mode in LearningAidMode.values) {
              expect(
                shouldShowCorrectionMarks(
                  isOutgoing: outgoing,
                  languagesMatchedAtSend: matched,
                  mode: mode,
                  sourceLanguageCode: source,
                  learningLanguageCode: 'de',
                ),
                mode == LearningAidMode.correction &&
                    source == 'de' &&
                    (outgoing || matched),
              );
            }
          }
        }
      }
    },
  );
  test('API provenance survives optional word metadata absence', () async {
    final translator = MessageTranslator(
      invoke: ({required messageId}) async => {
        'translation': 'Ich bin müde.',
        'interfaceText': 'I am tired.',
        'interfaceLang': 'en',
        'sourceLang': 'de',
        'mode': 'correction',
        'explanation': 'Use bin with ich.',
        'confidence': 'high',
        'tokens': [
          {'blabAuthoredCorrection': a},
        ],
      },
    );
    final r = await translator.translate(messageId: 'synthetic');
    expect(r.authoredCorrection, a);
    expect(r.tokens, isEmpty);
    expect(r.explanation, 'Use bin with ich.');
  });
}
