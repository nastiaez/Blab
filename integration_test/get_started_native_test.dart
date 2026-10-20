import 'dart:io';
import 'package:blab/app/theme.dart';
import 'package:blab/features/onboarding/welcome_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('BLA-18 opening CTA preserves callback', (tester) async {
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    var advances = 0;
    for (final entry in const {
      'en': 'Get started',
      'de': 'Los geht’s',
      'es': 'Comenzar',
      'uk': 'Розпочати',
    }.entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: blabTheme,
          locale: Locale(entry.key),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: WelcomeScreen(
            interfaceLanguageCode: entry.key,
            onContinue: () => advances++,
            onChangeInterfaceLanguage: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => precacheImage(
        const AssetImage('assets/onboarding/reading-nook.png'),
        tester.element(find.byType(WelcomeScreen)),
      ));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      await binding.takeScreenshot('welcome-${entry.key}');
      await tester.tap(find.text(entry.value));
      await tester.pumpAndSettle();
    }
    expect(advances, 4);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
