import 'package:blab/app/theme.dart';
import 'package:blab/app/onboarding_tokens.dart';
import 'package:blab/features/onboarding/learn_in_context_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/deep_dive/Roboto-Variable.ttf'));
    await loader.load();
  });
  testWidgets('Demo1 compact header fits normal phone widths', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [360.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpWidget(
        MaterialApp(
          theme: blabTheme,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: LearnInContextScreen(
            interfaceLanguageCode: 'en',
            onBack: () {},
            onContinue: () {},
            onChangeInterfaceLanguage: (_) async {},
            onPlayAudio: () async {},
            onStopAudio: () async {},
          ),
        ),
      );
      await tester.pump();
      final title = find.text('Build natural sentences');
      final subtitle = find.text(
        'Chat with friends. Blab corrects and translates.',
      );
      expect(
        tester.getTopLeft(subtitle).dy - tester.getBottomLeft(title).dy,
        closeTo(8, 0.01),
      );
      expect(tester.getSize(subtitle).height, closeTo(20, 0.01));
      expect(tester.widget<Text>(subtitle).style!.color, OnboardingTheme.muted);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
