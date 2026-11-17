import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:blab/features/chat/message_presentation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blab/features/chat/deep_dive_snapshot.dart';
import 'package:blab/features/chat/widgets/inline_correction_text.dart';

void main() {
  // Synthetic explicit-provenance regression: no private retained-provider file.
  final packages = <Map<String, dynamic>>[
    for (final known in ['en', 'uk'])
      {
        'message_id': 'synthetic-correction-$known',
        'chat_id': 'synthetic-chat',
        'translation_text': 'Ayer yo fui al mercado.',
        'interface_text': 'Known-language fixture',
        'primary_known_language': known,
        'source_lang': 'es',
        'learning_language': 'es',
        'aid_mode': 'correction',
        'tokens': [
          {
            'blabAuthoredCorrection': {
              'version': 'a-v2',
              'source': 'Ayer yo va al mercado.',
              'correctionText': 'Ayer yo fui al mercado.',
              'targetText': 'Ayer yo fui al mercado.',
              'corrections': [
                {
                  'start': 8,
                  'end': 10,
                  'original': 'va',
                  'replacement': 'fui',
                  'occurrence': 0,
                  'targetAnchor': null,
                },
              ],
            },
          },
        ],
        'form_alternatives': {
          'blabGenerationEnvelope': {'source': 'Ayer yo va al mercado.'},
        },
      },
  ];
  for (final p in packages) {
    test(
      'synthetic explicit provenance ${p['message_id']} ${p['primary_known_language']}',
      () {
        final raw = Map<String, dynamic>.from(
          p['tokens'][0]['blabAuthoredCorrection'],
        );
        final mapped = replayExactCorrectionAnchors(raw)!;
        for (final outgoing in [true, false]) {
          for (final matched in [true, false]) {
            final snapshot = deepDiveSnapshot(
              message: Message(
                id: p['message_id'],
                chatId: p['chat_id'],
                isOutgoing: outgoing,
                originalText: raw['source'],
                translation: p['translation_text'],
                sentAt: DateTime(2026),
                status: MessageStatus.delivered,
                languagesMatchedAtSend: matched,
              ),
              presentation: MessagePresentation(
                primaryText: p['translation_text'],
                originalText: raw['source'],
                canRevealOriginal: true,
              ),
              value: MessageTranslation(
                translation: p['translation_text'],
                interfaceText: p['interface_text'],
                interfaceLang: p['primary_known_language'],
                sourceLang: p['source_lang'],
                tokens: const [],
                mode: p['aid_mode'] == 'correction'
                    ? LearningAidMode.correction
                    : LearningAidMode.translation,
                confidence: CorrectionConfidence.high,
                authoredCorrection: raw,
                generationEnvelope: Map<String, dynamic>.from(
                  p['form_alternatives']['blabGenerationEnvelope'],
                ),
              ),
              mode: ChatMode.practice,
              learningLanguageCode: p['learning_language'],
            );
            expect(
              snapshot.corrections.isNotEmpty,
              (raw['corrections'] as List).isNotEmpty && (outgoing || matched),
            );
          }
        }
        expect(
          raw['corrections'].every((c) => c['targetAnchor'] == null),
          isTrue,
        );
        if ((raw['corrections'] as List).isEmpty) {
          expect(mapped['corrections'], isEmpty);
          return;
        }
        final row = mapped['corrections'][0];
        expect(row['original'], 'va');
        expect(row['replacement'], 'fui');
        expect(row['start'], 8);
        expect(row['end'], 10);
        expect(row['targetAnchor']['start'], 8);
        expect(
          translatedCorrectionSegments(
            raw['source'],
            raw['targetText'],
            mapped,
          ).any((s) => s.struck),
          isTrue,
        );
        expect(
          replayExactCorrectionAnchors({
            ...raw,
            'targetText': 'Unrelated generated sentence',
          }),
          {...raw, 'targetText': 'Unrelated generated sentence'},
        );
      },
    );
  }
}
