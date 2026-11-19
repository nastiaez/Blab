import 'dart:async';
import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/deep_dive_screen.dart';
import 'package:blab/features/chat/widgets/inline_correction_text.dart';
import 'package:blab/shared/services/deep_dive_service.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'deep_dive_screen_test.dart' show FakeSpeech;

void main() {
  testWidgets(
    'physical single taps switch pending mistakes and word overlays',
    (tester) async {
      final requests = <Map<String, dynamic>>[];
      final pending = <Completer<Map<String, dynamic>>>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ttsServiceProvider.overrideWithValue(FakeSpeech()),
            deepDiveServiceProvider.overrideWithValue(
              DeepDiveService(
                viewerId: () => 'offline',
                invoke: (r) {
                  requests.add(r);
                  final c = Completer<Map<String, dynamic>>();
                  pending.add(c);
                  return c.future;
                },
              ),
            ),
          ],
          child: MaterialApp(
            theme: blabTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DeepDiveScreen(
              messageId: 'switch',
              authoredText: 'I goed home and eated bread.',
              displayText: 'I went home and ate bread.',
              learningLanguageCode: 'en',
              knownLanguageCode: 'de',
              aidsEnabled: true,
              segments: const [
                CorrectionSegment('I '),
                CorrectionSegment('goed', struck: true),
                CorrectionSegment('went', corrected: true),
                CorrectionSegment(' home and '),
                CorrectionSegment('eated', struck: true),
                CorrectionSegment('ate', corrected: true),
                CorrectionSegment(' bread.'),
              ],
              corrections: const [
                {
                  'start': 2,
                  'end': 6,
                  'original': 'goed',
                  'replacement': 'went',
                  'targetAnchor': {'start': 2},
                },
                {
                  'start': 16,
                  'end': 21,
                  'original': 'eated',
                  'replacement': 'ate',
                  'targetAnchor': {'start': 16},
                },
              ],
            ),
          ),
        ),
      );
      Future<void> tap(String text) async {
        await tester.tap(find.text(text).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }

      String heading() => tester
          .widget<Text>(find.byKey(const ValueKey('deep-dive-mistake-heading')))
          .textSpan!
          .toPlainText();
      await tap('goed');
      expect(heading(), 'goed → went');
      await tap('goed');
      expect(
        find.byKey(const ValueKey('deep-dive-mistake-heading')),
        findsNothing,
      );
      pending[0].complete({'meaning': 'first', 'explanation': 'LATE FIRST'});
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('deep-dive-mistake-heading')),
        findsNothing,
      );
      await tap('goed');
      expect(heading(), 'goed → went');
      await tap('eated');
      expect(heading(), 'eated → ate');
      expect(pending, hasLength(2));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending[1].complete({'meaning': 'second', 'explanation': 'SECOND'});
      await tester.pump();
      await tester.pump();
      expect(find.text('SECOND'), findsOneWidget);
      expect(find.text('LATE FIRST'), findsNothing);
      expect(find.text('SECOND'), findsOneWidget);
      await tap('goed');
      expect(heading(), 'goed → went');
      expect(find.text('SECOND'), findsNothing);
      await tap('goed');
      expect(
        find.byKey(const ValueKey('deep-dive-mistake-heading')),
        findsNothing,
      );
      await tap('goed');
      expect(heading(), 'goed → went');
      await tap('went');
      expect(
        find.byKey(const ValueKey('deep-dive-mistake-heading')),
        findsNothing,
      );
      await tap('home');
      expect(requests.last['kind'], 'vocabulary');
      expect(requests.last['start'], 7);
      final home = pending.length - 1;
      await tap('ate');
      expect(requests.last['start'], 16);
      final ate = pending.length - 1;
      expect(find.text('HOME LATE'), findsNothing);
      // The first word is still pending when both later selections occur.
      pending[2].completeError(StateError('late dismissed word'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      pending[ate].complete({'meaning': 'ATE CURRENT'});
      await tester.pump();
      await tester.pump();
      pending[home].complete({'meaning': 'HOME LATE'});
      await tester.pump();
      expect(find.text('HOME LATE'), findsNothing);
      expect(find.text('ATE CURRENT'), findsOneWidget);
      await tap('eated');
      expect(heading(), 'eated → ate');
      expect(find.text('ATE CURRENT'), findsNothing);
      expect(find.text('SECOND'), findsOneWidget);
      await tap('bread.');
      expect(
        find.byKey(const ValueKey('deep-dive-mistake-heading')),
        findsNothing,
      );
      expect(requests.last['start'], 20);
      await tester.pumpWidget(const SizedBox());
      for (final c in pending) {
        if (!c.isCompleted) {
          c.complete({'meaning': 'DISPOSED', 'explanation': 'DISPOSED'});
        }
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'error repeat closes, reopening and explicit retry remain usable',
    (tester) async {
      final requests = <Map<String, dynamic>>[];
      final pending = <Completer<Map<String, dynamic>>>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ttsServiceProvider.overrideWithValue(FakeSpeech()),
            deepDiveServiceProvider.overrideWithValue(
              DeepDiveService(
                viewerId: () => 'offline',
                invoke: (r) {
                  requests.add(r);
                  final c = Completer<Map<String, dynamic>>();
                  pending.add(c);
                  return c.future;
                },
              ),
            ),
          ],
          child: MaterialApp(
            theme: blabTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DeepDiveScreen(
              messageId: 'retry-toggle',
              authoredText: 'I goed home and eated bread.',
              displayText: 'I went home and ate bread.',
              learningLanguageCode: 'en',
              knownLanguageCode: 'de',
              aidsEnabled: true,
              segments: const [
                CorrectionSegment('I '),
                CorrectionSegment('goed', struck: true),
                CorrectionSegment('went', corrected: true),
                CorrectionSegment(' home and '),
                CorrectionSegment('eated', struck: true),
                CorrectionSegment('ate', corrected: true),
                CorrectionSegment(' bread.'),
              ],
              corrections: const [
                {
                  'start': 2,
                  'end': 6,
                  'original': 'goed',
                  'replacement': 'went',
                  'targetAnchor': {'start': 2},
                },
                {
                  'start': 16,
                  'end': 21,
                  'original': 'eated',
                  'replacement': 'ate',
                  'targetAnchor': {'start': 16},
                },
              ],
            ),
          ),
        ),
      );

      Future<void> tap(String text) async {
        await tester.tap(find.text(text).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }

      final heading = find.byKey(const ValueKey('deep-dive-mistake-heading'));
      await tap('goed');
      pending[0].completeError(StateError('synthetic unavailable'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Retry'), findsOneWidget);
      await tap('goed');
      expect(heading, findsNothing);
      await tap('goed');
      expect(heading, findsOneWidget);
      await tester.pump();
      if (pending.length > 1) {
        pending.last.completeError(StateError('synthetic unavailable again'));
        await tester.pump();
        await tester.pump();
      }
      final before = pending.length;
      await tap('Retry');
      expect(heading, findsOneWidget);
      expect(pending.length, before + 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.last.complete({'meaning': 'ging', 'explanation': 'RECOVERED'});
      await tester.pump();
      await tester.pump();
      expect(find.text('RECOVERED'), findsOneWidget);
      await tap('goed');
      expect(heading, findsNothing);
      await tap('goed');
      expect(find.text('RECOVERED'), findsOneWidget);
      expect(pending.length, before + 1);
    },
  );
}
