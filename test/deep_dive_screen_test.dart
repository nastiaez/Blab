import 'dart:async';
import 'package:blab/features/chat/deep_dive_screen.dart';
import 'package:blab/features/chat/widgets/inline_correction_text.dart';
import 'package:blab/shared/services/deep_dive_service.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSpeech extends TtsService {
  int stops = 0;
  bool available = true;
  @override
  Future<bool> isLanguageAvailable(String code) async => available;
  @override
  Future<bool> speakWithStatus(String text, String code) async => available;
  @override
  Future<void> stop() async {
    stops++;
  }
}

const corrections = [
  {
    'start': 4,
    'end': 8,
    'original': 'bing',
    'replacement': 'bin',
    'targetAnchor': {'start': 4, 'end': 7},
  },
  {
    'start': 9,
    'end': 13,
    'original': 'bing',
    'replacement': 'bin',
    'targetAnchor': {'start': 8, 'end': 11},
  },
];
Widget harness({
  required DeepDiveService service,
  required FakeSpeech speech,
  bool aids = true,
  double scale = 1,
  String source = 'Ich bing bing.',
}) => ProviderScope(
  overrides: [
    deepDiveServiceProvider.overrideWithValue(service),
    ttsServiceProvider.overrideWithValue(speech),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: DeepDiveScreen(
      messageId: 'm',
      authoredText: source,
      displayText: 'Ich bin bin.',
      learningLanguageCode: 'de',
      knownLanguageCode: 'uk',
      aidsEnabled: aids,
      translation: 'Translation',
      listenText: 'Ich bin bin.',
      corrections: corrections,
      segments: const [
        CorrectionSegment('Ich '),
        CorrectionSegment('bing', struck: true),
        CorrectionSegment('bin', corrected: true),
        CorrectionSegment(' '),
        CorrectionSegment('bing', struck: true),
        CorrectionSegment('bin', corrected: true),
        CorrectionSegment('.'),
      ],
    ),
  ),
);
void main() {
  testWidgets(
    'mistake selection replaces translation, repeated words retain identity; no stale result',
    (tester) async {
      final pending = <Completer<Map<String, dynamic>>>[];
      final starts = <Object?>[];
      final service = DeepDiveService(
        viewerId: () => 'a',
        invoke: (r) {
          starts.add(r['start']);
          final c = Completer<Map<String, dynamic>>();
          pending.add(c);
          return c.future;
        },
      );
      final speech = FakeSpeech();
      await tester.pumpWidget(harness(service: service, speech: speech));
      await tester.tap(find.byTooltip('Translate'));
      await tester.pump();
      expect(find.text('Translation'), findsOneWidget);
      await tester.tap(find.text('bing').first);
      await tester.pump();
      expect(find.text('Translation'), findsNothing);
      await tester.tap(find.text('bing').at(1));
      await tester.pump();
      expect(starts, [4, 9]);
      pending[1].complete({
        'meaning': 'be',
        'explanation': 'Second explanation',
      });
      await tester.pump();
      await tester.pump();
      pending[0].complete({
        'meaning': 'be',
        'explanation': 'Stale explanation',
      });
      await tester.pumpAndSettle();
      expect(find.text('Second explanation'), findsOneWidget);
      expect(find.text('Stale explanation'), findsNothing);
      await tester.tap(find.byTooltip('Translate'));
      await tester.pump();
      expect(find.text('Second explanation'), findsNothing);
      expect(find.text('Translation'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(speech.stops, greaterThan(0));
    },
  );
  testWidgets(
    'aids off has no learning controls or service requests at large text',
    (tester) async {
      var calls = 0;
      final speech = FakeSpeech();
      await tester.pumpWidget(
        harness(
          service: DeepDiveService(
            viewerId: () => 'a',
            invoke: (_) async {
              calls++;
              return {'meaning': 'x'};
            },
          ),
          speech: speech,
          aids: false,
          scale: 2,
        ),
      );
      expect(find.byTooltip('Listen'), findsNothing);
      expect(find.byTooltip('Translate'), findsNothing);
      expect(calls, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('audio failure and retry do not hide a readable translation', (
    tester,
  ) async {
    final speech = FakeSpeech()..available = false;
    final service = DeepDiveService(
      viewerId: () => 'a',
      invoke: (_) async => {'meaning': 'be'},
    );
    await tester.pumpWidget(harness(service: service, speech: speech));
    await tester.tap(find.byTooltip('Translate'));
    await tester.pump();
    await tester.tap(find.byTooltip('Listen'));
    await tester.pumpAndSettle();
    expect(find.text('Audio unavailable'), findsOneWidget);
    expect(find.text('Translation'), findsOneWidget);
    speech.available = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Audio unavailable'), findsNothing);
    expect(find.text('Translation'), findsOneWidget);
  });
  testWidgets(
    'ordinary popup uses contextual lookup and opens vocabulary details',
    (tester) async {
      final speech = FakeSpeech();
      final service = DeepDiveService(
        viewerId: () => 'a',
        invoke: (request) async => request['mode'] == 'short'
            ? {'meaning': 'I'}
            : {
                'meaning': 'I',
                'gender': 'neuter',
                'pronunciation': '/test/',
                'grammarTable': [
                  {'label': 'First person', 'value': 'ich'},
                ],
                'examples': [
                  {'text': 'Ich lerne.', 'translation': 'I learn.'},
                ],
              },
      );
      await tester.pumpWidget(harness(service: service, speech: speech));
      await tester.tap(find.text('Ich'));
      await tester.pumpAndSettle();
      expect(find.text('I'), findsOneWidget);
      expect(find.text('More details'), findsOneWidget);
      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();
      expect(find.text('Word details'), findsOneWidget);
      expect(find.text('Ich lerne.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Deep Dive'), findsOneWidget);
    },
  );
  testWidgets(
    'authored edit with identical displayed text closes old explanation and ignores late completion',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      final service = DeepDiveService(
        viewerId: () => 'a',
        invoke: (_) => pending.future,
      );
      final speech = FakeSpeech();
      await tester.pumpWidget(harness(service: service, speech: speech));
      await tester.tap(find.text('bing').first);
      await tester.pump();
      expect(find.text('WHY THIS MISTAKE?'), findsOneWidget);
      await tester.pumpWidget(
        harness(
          service: service,
          speech: speech,
          source: 'Edited authored wording',
        ),
      );
      await tester.pump();
      expect(find.text('WHY THIS MISTAKE?'), findsNothing);
      pending.complete({
        'meaning': 'be',
        'explanation': 'Obsolete source explanation',
      });
      await tester.pumpAndSettle();
      expect(find.text('Obsolete source explanation'), findsNothing);
    },
  );
  testWidgets('selectable words honor system text scaling exactly once', (
    tester,
  ) async {
    final service = DeepDiveService(
      viewerId: () => 'a',
      invoke: (_) async => {'meaning': 'm', 'explanation': 'e'},
    );
    final speech = FakeSpeech();
    await tester.pumpWidget(harness(service: service, speech: speech));
    await tester.pumpAndSettle();
    final normal = tester.getRect(find.text('bin').first);
    await tester.pumpWidget(
      harness(service: service, speech: speech, scale: 2),
    );
    await tester.pumpAndSettle();
    final large = tester.getRect(find.text('bin').first);
    expect(large.width / normal.width, closeTo(2, .03));
    expect(large.height / normal.height, closeTo(2, .03));
    expect(tester.takeException(), isNull);
  });
  test(
    'long quoted phrase heading abbreviates presentation, never source content',
    () {
      const full = 'weil ich „Glass Skin Makeup“ probieren möchte';
      expect(deepDiveCorrectionHeading(full), 'weil ich ... probieren möchte');
      expect(deepDiveCorrectionHeading('bin'), 'bin');
      const unquoted =
          'this deliberately long source phrase has no quoted object';
      expect(deepDiveCorrectionHeading(unquoted), unquoted);
      expect(full, contains('Glass Skin Makeup'));
    },
  );
}
