import 'dart:async';
import 'package:blab/shared/widgets/skeletons.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/deep_dive_screen.dart';
import 'package:blab/features/chat/widgets/deep_dive_word_popup.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/services/deep_dive_service.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class Speech extends TtsService {
  @override
  Future<void> stop() async {}
}

void main() {
  testWidgets(
    'unverified English metadata never leaks during Known Ukrainian lookup lifecycle',
    (tester) async {
      final requests = <Map<String, dynamic>>[];
      final pending = <Completer<Map<String, dynamic>>>[];
      final service = DeepDiveService(
        viewerId: () => 'bob',
        invoke: (r) {
          requests.add(r);
          final c = Completer<Map<String, dynamic>>();
          pending.add(c);
          return c.future;
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deepDiveServiceProvider.overrideWithValue(service),
            ttsServiceProvider.overrideWithValue(Speech()),
          ],
          child: MaterialApp(
            theme: blabTheme,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DeepDiveScreen(
              messageId: 'm',
              authoredText: 'Hoy',
              displayText: 'Hoy',
              learningLanguageCode: 'es',
              knownLanguageCode: 'uk',
              aidsEnabled: true,
              tokens: [MessageToken(text: 'Hoy', gloss: 'Today')],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Hoy'));
      await tester.pump();
      expect(find.text('Today'), findsNothing);
      expect(find.byType(SkeletonTextLine), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(requests.single['knownLang'], 'uk');
      expect(requests.single['targetLang'], 'es');
      pending.single.completeError(const DeepDiveUnavailable());
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsNothing);
      expect(find.text('Couldn’t translate · Retry'), findsOneWidget);
      await tester.tap(find.text('Couldn’t translate · Retry'));
      await tester.pump();
      expect(find.text('Today'), findsNothing);
      pending.last.complete({'meaning': 'Сьогодні'});
      await tester.pumpAndSettle();
      expect(find.text('Сьогодні'), findsOneWidget);
      expect(find.text('Today'), findsNothing);
      expect(find.text('More details'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'German failure full-width text and reachable retry at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await (FontLoader('BlabDeepDiveRoboto')..addFont(
              rootBundle.load('assets/fonts/deep_dive/Roboto-Variable.ttf'),
            ))
            .load();
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: blabTheme,
            locale: const Locale('de'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Center(
                  child: DeepDiveWordPopup(
                    text: 'Ayer',
                    languageCode: 'es',
                    tts: Speech(),
                    onDetails: (_) {},
                    load: (_) async {
                      calls++;
                      throw const DeepDiveUnavailable();
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final error = find.text(
          'Übersetzung fehlgeschlagen · Erneut versuchen',
        );
        expect(error, findsOneWidget);
        expect(tester.getSize(error).width, 220);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: error, matching: find.byType(RichText)),
        );
        if (scale == 1) {
          expect(
            paragraph.getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 11),
            ),
            hasLength(1),
            reason:
                'Übersetzung must remain intact in the shared tappable notice',
          );
        }
        expect(tester.getSize(find.byType(DeepDiveWordPopup)).width, 254);
        final retry = find.text(
          'Übersetzung fehlgeschlagen · Erneut versuchen',
        );
        await tester.ensureVisible(retry);
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(calls, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
