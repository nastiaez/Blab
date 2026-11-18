import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final font = await rootBundle.load(
      'assets/fonts/deep_dive/Roboto-Variable.ttf',
    );
    for (final family in ['BlabDeepDiveRoboto', 'Roboto']) {
      await (FontLoader(family)..addFont(Future.value(font))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final prefix in ['', '🙂 é ']) {
    for (final originalWord in ['Uhr', 'Uhrzeit']) {
      testWidgets(
        'legacy corrections preserve complete word identity $prefix $originalWord',
        (tester) async {
          final source =
              '${prefix}I’m denke nach 16 Uhr. Was denkst du? Passt die $originalWord für dich?';
          final target =
              '${prefix}Ich denke nach 16 Uhr. Was denkst du? Passt die Uhrzeit für dich?';
          await tester.binding.setSurfaceSize(const Size(390, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final captureKey = GlobalKey();
          Future<void> capture(String name) async {
            if (!const bool.fromEnvironment('BLA59_CAPTURE')) return;
            await tester.runAsync(() async {
              final boundary =
                  captureKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File('qa-artifacts/bla59/$name.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          final requests = <Map<String, dynamic>>[];
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
                        'meaning': 'time (of day)',
                        'explanation':
                            'The complete noun names the time of day.',
                      };
                    },
                  ),
                ),
              ],
              child: RepaintBoundary(
                key: captureKey,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: blabTheme,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: DeepDiveScreen(
                    messageId: 'm',
                    authoredText: source,
                    displayText: target,
                    learningLanguageCode: 'de',
                    knownLanguageCode: 'en',
                    aidsEnabled: true,
                    segments: correctionSegments(source, target),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Uhrzeit'));
          await tester.pumpAndSettle();
          expect(requests, hasLength(1));
          final request = requests.single;
          expect(
            target.substring(request['start'] as int, request['end'] as int),
            'Uhrzeit',
          );
          expect(request['start'], target.indexOf('Uhrzeit'));
          if (prefix.isEmpty && originalWord == 'Uhr') {
            await capture('01-popup-widget-fixture');
          }
          await tester.tap(find.text('More details'));
          await tester.pumpAndSettle();
          expect(find.text('Uhrzeit'), findsOneWidget);
          expect(find.text('hrzeit'), findsNothing);
          expect(request['targetLang'], 'de');
          expect(request['knownLang'], 'en');
          expect(request['acceptedText'], target);
          expect(request['sourceText'], source);
          if (prefix.isEmpty && originalWord == 'Uhr') {
            await capture('02-details-widget-fixture');
          }
        },
      );
    }
  }
}
