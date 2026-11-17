import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/deep_dive_screen.dart';
import 'package:blab/features/chat/deep_dive_typography.dart';
import 'package:blab/features/chat/widgets/word_popup.dart';
import 'package:blab/shared/services/deep_dive_service.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/deep_dive_word_fixture.dart' as fixture;

void main() {
  testWidgets(
    '20582 selected-only dots disappear; dismiss and switch restore without geometry shift',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deepDiveServiceProvider.overrideWithValue(
              DeepDiveService(
                viewerId: () => 'fixture',
                invoke: (_) async => fixture.word('Bücher', 'neuter'),
              ),
            ),
            ttsServiceProvider.overrideWithValue(fixture.FixtureTts()),
          ],
          child: MaterialApp(
            theme: blabTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DeepDiveScreen(
              messageId: '20582-UI-only',
              authoredText: 'Am Samstag kaufe ich Bücher.',
              displayText: 'Am Samstag kaufe ich Bücher.',
              learningLanguageCode: 'de',
              knownLanguageCode: 'en',
              aidsEnabled: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder word(String text) => find.descendant(
        of: find.byType(DeepDiveWordDots),
        matching: find.text(text),
      );
      DeepDiveWordDots dots(String text) => tester.widget(
        find.ancestor(of: word(text), matching: find.byType(DeepDiveWordDots)),
      );
      final before = {
        for (final t in ['Am', 'Samstag', 'kaufe', 'ich', 'Bücher.'])
          t: tester.getRect(word(t)),
      };
      await tester.tap(word('Bücher.'));
      await tester.pumpAndSettle();
      expect(dots('Bücher.').enabled, false);
      expect(dots('Am').enabled, true);
      for (final t in before.keys) {
        expect(tester.getRect(word(t)), before[t]);
      }
      await tester.tap(word('Am'));
      await tester.pumpAndSettle();
      expect(dots('Bücher.').enabled, true);
      expect(dots('Am').enabled, false);
      for (final t in before.keys) {
        expect(tester.getRect(word(t)), before[t]);
      }
      dismissWordPopup();
      await tester.pumpAndSettle();
      for (final t in before.keys) {
        expect(dots(t).enabled, true);
        expect(tester.getRect(word(t)), before[t]);
      }
      await tester.tap(word('Am'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(350, 750));
      await tester.pumpAndSettle();
      expect(dots('Am').enabled, true);
      await tester.tap(word('Am'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
