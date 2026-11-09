import 'dart:convert';
import 'package:blab/features/chat/widgets/inline_correction_text.dart';
import 'package:blab/features/chat/widgets/message_text.dart';
import 'package:blab/features/chat/widgets/message_learning_content.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/services/local_chat_history_cache.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const source = 'Ich ist tired; sie ist busy.';
final provenance = <String, dynamic>{
  'version': 'a-v1',
  'source': source,
  'correctionText': 'Ich bin tired; sie ist busy.',
  'corrections': [
    {'original': 'ist', 'replacement': 'bin', 'start': 4, 'end': 7},
  ],
};
Map<String, dynamic> payload({
  Object? metadata,
  bool envelope = true,
  Object? confidence = 'high',
}) => {
  'translation': 'Ich bin müde; sie ist beschäftigt.',
  'interfaceText': 'I am tired; she is busy.',
  'interfaceLang': 'en',
  'sourceLang': 'de',
  'mode': 'correction',
  'explanation': null,
  'confidence': confidence,
  'tokens': [
    if (metadata != null) {'blabAuthoredCorrection': metadata},
  ],
  'formAlternatives': envelope
      ? {
          'blabGenerationEnvelope': {'version': 'a-v1', 'source': source},
        }
      : null,
};
Widget host(
  MessageTranslation value, {
  bool outgoing = true,
  bool matched = true,
  bool aids = true,
  ChatMode mode = ChatMode.practice,
  String learning = 'de',
}) => ProviderScope(
  child: MaterialApp(
    home: Scaffold(
      body: MessageLearningContent(
        authoredText: source,
        translation: AsyncData(value),
        showTranslation: aids,
        learningLanguageCode: learning,
        isOutgoing: outgoing,
        languagesMatchedAtSend: matched,
        popupTopInset: 0,
        unavailableText: 'Unavailable',
        retryText: 'Retry',
        mode: mode,
        knownLanguageCodes: const ['de'],
        expanded: true,
        onToggleExpanded: () {},
      ),
    ),
  ),
);
Future<MessageTranslation> decode(Map<String, dynamic> raw) =>
    MessageTranslator(
      invoke: ({required messageId}) async =>
          jsonDecode(jsonEncode(raw)) as Map<String, dynamic>,
    ).translate(messageId: 'fixture');
void main() {
  testWidgets(
    'new generation shows full translation plus only explicit source correction',
    (tester) async {
      await tester.pumpWidget(
        host(await decode(payload(metadata: provenance))),
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is MessageText &&
              w.text == 'Ich bin müde; sie ist beschäftigt.',
        ),
        findsOneWidget,
      );
      final inline = tester.widget<InlineCorrectionText>(
        find.byType(InlineCorrectionText),
      );
      expect(inline.segments!.where((s) => s.struck).map((s) => s.text), [
        'ist',
      ]);
      expect(inline.segments!.where((s) => s.corrected).map((s) => s.text), [
        'bin',
      ]);
      expect(find.text('I am tired; she is busy.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final entry in <String, Object?>{
    'missing': null,
    'malformed': {},
    'stale': {...provenance, 'source': 'stale'},
    'unknown': {...provenance, 'version': 'unknown'},
  }.entries) {
    testWidgets(
      'new generation ${entry.key} metadata never invokes legacy diff',
      (tester) async {
        await tester.pumpWidget(
          host(await decode(payload(metadata: entry.value))),
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is MessageText &&
                w.text == 'Ich bin müde; sie ist beschäftigt.',
          ),
          findsOneWidget,
        );
        expect(find.byType(InlineCorrectionText), findsNothing);
      },
    );
  }
  testWidgets('true legacy retains historical inline-diff behavior', (
    tester,
  ) async {
    await tester.pumpWidget(host(await decode(payload(envelope: false))));
    expect(find.byType(InlineCorrectionText), findsOneWidget);
  });
  testWidgets(
    'unknown confidence suppresses marks but retains both sentences',
    (tester) async {
      await tester.pumpWidget(
        host(
          await decode(payload(metadata: provenance, confidence: 'unknown')),
        ),
      );
      expect(find.byType(InlineCorrectionText), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is MessageText &&
              w.text == 'Ich bin müde; sie ist beschäftigt.',
        ),
        findsOneWidget,
      );
      expect(find.text('I am tired; she is busy.'), findsOneWidget);
    },
  );
  testWidgets('viewer send-time, language, Normal and aids-off gates remain', (
    tester,
  ) async {
    final value = await decode(payload(metadata: provenance));
    for (final flags in [
      (false, false, true, ChatMode.practice, 'de'),
      (true, true, true, ChatMode.normal, 'de'),
      (true, true, false, ChatMode.practice, 'de'),
      (true, true, true, ChatMode.practice, 'es'),
    ]) {
      await tester.pumpWidget(
        host(
          value,
          outgoing: flags.$1,
          matched: flags.$2,
          aids: flags.$3,
          mode: flags.$4,
          learning: flags.$5,
        ),
      );
      expect(find.byType(InlineCorrectionText), findsNothing);
    }
  });
  test(
    'capitalization-only corrections are mechanically unmarked; stale correctionText rejected',
    () {
      for (final pair in [
        ('haus', 'Haus'),
        ('hello!', 'Hello'),
        ('foo bar', 'foobar'),
      ]) {
        final rows = authoredCorrectionSegments(pair.$1, {
          'version': 'a-v1',
          'source': pair.$1,
          'correctionText': pair.$2,
          'corrections': [
            {
              'original': pair.$1,
              'replacement': pair.$2,
              'start': 0,
              'end': pair.$1.length,
            },
          ],
        });
        expect(rows.any((s) => s.struck || s.corrected), false);
      }
      expect(
        authoredCorrectionSegments(source, {
          ...provenance,
          'correctionText': 'invented',
        }).any((s) => s.struck),
        false,
      );
    },
  );
  test(
    'readable package and real local save/load preserve independent envelope with empty tokens',
    () async {
      SharedPreferences.setMockInitialValues({});
      final raw = payload()
        ..['generationEnvelope'] = {'version': 'a-v1', 'source': source};
      raw.remove('tokens');
      final row = readablePreparedPackage({
        'message_id': 'm',
        'chat_id': 'c',
        'viewer_id': 'u',
        'target_lang': 'de',
        'learning_language': 'de',
        'interface_lang': 'en',
        'language_revision': 1,
        'source_hash': sha256.convert(utf8.encode(source)).toString(),
        'result': raw,
      })!;
      await LocalChatHistoryCache(
        'u',
      ).savePreparedTranslations('c', [row], sourceTexts: {'m': source});
      final loaded = (await LocalChatHistoryCache(
        'u',
      ).loadPreparedTranslations('c')).single;
      expect(parseGenerationEnvelope(loaded), {
        'version': 'a-v1',
        'source': source,
      });
      expect(loaded['tokens'], isNotEmpty);
      expect(parseAuthoredCorrection(loaded['tokens']), isNull);
      final restored = await decode({
        ...raw,
        'formAlternatives': loaded['form_alternatives'],
        'tokens': [],
      });
      expect(restored.sourceScopedGeneration, true);
    },
  );
  test(
    'unchanged subject anchors and capitalization inside genuine spans stay unmarked',
    () {
      final rows = authoredCorrectionSegments('ich ist tired', {
        'version': 'a-v1',
        'source': 'ich ist tired',
        'correctionText': 'Ich bin tired',
        'corrections': [
          {
            'start': 0,
            'end': 7,
            'original': 'ich ist',
            'replacement': 'Ich bin',
          },
        ],
      });
      expect(rows.where((s) => s.struck).map((s) => s.text), ['ist']);
      expect(rows.where((s) => s.corrected).map((s) => s.text), ['bin']);
      expect(
        rows.where((s) => !s.struck).map((s) => s.text).join(),
        'Ich bin tired',
      );
    },
  );
}
