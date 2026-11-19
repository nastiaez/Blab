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
  for (final languages in [('es', 'en'), ('de', 'uk')]) {
    for (final enabled in [true, false]) {
      testWidgets(
        'replacement words use word lookup $languages enabled=$enabled',
        (tester) async {
          final requests = <Map<String, dynamic>>[];
          const source = '🙂 I goed home.';
          const target = '🙂 I went back home.';
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                ttsServiceProvider.overrideWithValue(FakeSpeech()),
                deepDiveServiceProvider.overrideWithValue(
                  DeepDiveService(
                    viewerId: () => 'viewer',
                    invoke: (r) async {
                      requests.add(r);
                      return {
                        'meaning': 'Synthetic word meaning',
                        'explanation': 'Synthetic mistake explanation',
                      };
                    },
                  ),
                ),
              ],
              child: MaterialApp(
                theme: blabTheme,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: DeepDiveScreen(
                  messageId: 'bla57',
                  authoredText: source,
                  displayText: target,
                  learningLanguageCode: languages.$1,
                  knownLanguageCode: languages.$2,
                  aidsEnabled: true,
                  wordLookupEnabled: enabled,
                  // Producer provenance has adjacent struck/replacement runs, without
                  // the legacy diff's presentation-only separator.
                  segments: const [
                    CorrectionSegment('🙂 I '),
                    CorrectionSegment('goed', struck: true),
                    CorrectionSegment('went back', corrected: true),
                    CorrectionSegment(' home.'),
                  ],
                  corrections: const [
                    {
                      'start': 5,
                      'end': 9,
                      'original': 'goed',
                      'replacement': 'went back',
                      'targetAnchor': {'start': 5},
                    },
                  ],
                ),
              ),
            ),
          );
          await tester.tap(find.text('goed'));
          await tester.pumpAndSettle();
          expect(requests.single['kind'], 'correction');
          expect(requests.single['start'], 5);
          expect(find.text('Synthetic mistake explanation'), findsOneWidget);
          final heading = tester.widget<Text>(
            find.byKey(const ValueKey('deep-dive-mistake-heading')),
          );
          expect(heading.textSpan!.toPlainText(), 'goed → went back');
          final original =
              (heading.textSpan! as TextSpan).children!.first as TextSpan;
          expect(original.style!.decoration, TextDecoration.lineThrough);
          if (!enabled) {
            expect(find.text('went'), findsNothing);
            expect(requests, hasLength(1));
            return;
          }
          for (final word in ['went', 'back']) {
            if (word == 'back') {
              // Reopen from the original between words: each replacement must
              // independently clear the mistake, including a cached response.
              await tester.tap(find.text('goed').first);
              await tester.pumpAndSettle();
              expect(
                find.text('Synthetic mistake explanation'),
                findsOneWidget,
              );
            }
            await tester.tap(find.text(word).first);
            await tester.pumpAndSettle();
            if (enabled) {
              expect(requests.last['kind'], 'vocabulary');
              expect(
                target.substring(
                  requests.last['start'] as int,
                  requests.last['end'] as int,
                ),
                word,
              );
              expect(requests.last['targetLang'], languages.$1);
              expect(requests.last['knownLang'], languages.$2);
              expect(find.text('Synthetic word meaning'), findsOneWidget);
              expect(find.text('Synthetic mistake explanation'), findsNothing);
              expect(
                find.byKey(const ValueKey('deep-dive-mistake-heading')),
                findsNothing,
              );
              expect(
                requests.where((r) => r['kind'] == 'correction'),
                hasLength(1),
              );
            } else {
              expect(requests, hasLength(1));
            }
          }
        },
      );
    }
  }
}
