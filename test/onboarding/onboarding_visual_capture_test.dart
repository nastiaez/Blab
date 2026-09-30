import 'dart:io';

import 'package:blab/app/theme.dart';
import 'package:blab/features/auth/auth_screen.dart';
import 'package:blab/features/onboarding/auth/auth_method_screen.dart';
import 'package:blab/features/onboarding/confirm_name_screen.dart';
import 'package:blab/features/onboarding/language_you_understand_screen.dart';
import 'package:blab/features/onboarding/learn_in_context_screen.dart';
import 'package:blab/features/onboarding/welcome_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool reducedMotion = false}) {
  return ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: blabTheme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, content) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
        child: content!,
      ),
      home: child,
    ),
  );
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'capture approved onboarding review surfaces',
    (tester) async {
      _setViewport(tester);

      await tester.pumpWidget(
        _app(
          WelcomeScreen(
            interfaceLanguageCode: 'en',
            onContinue: () {},
            onChangeInterfaceLanguage: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../docs/qa/2026-09-30-onboarding-auth-refresh/430/welcome.png',
        ),
      );

      await tester.pumpWidget(
        _app(
          LearnInContextScreen(
            interfaceLanguageCode: 'en',
            onBack: () {},
            onContinue: () {},
            onChangeInterfaceLanguage: (_) async {},
            onPlayAudio: () async {},
            onStopAudio: () async {},
          ),
          reducedMotion: true,
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../docs/qa/2026-09-30-onboarding-auth-refresh/430/learn-reduced-motion.png',
        ),
      );

      await tester.pumpWidget(
        _app(
          AuthMethodScreen(
            mode: AuthMode.signUp,
            interfaceLanguageCode: 'en',
            onBack: () {},
            onGoogle: () async {},
            onEmail: () {},
            onSwitchMode: () {},
            onChangeInterfaceLanguage: (_) async {},
            onTerms: () {},
            onPrivacy: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../docs/qa/2026-09-30-onboarding-auth-refresh/430/signup-method.png',
        ),
      );

      await tester.pumpWidget(
        _app(
          ConfirmNameScreen(
            initialName: 'Nastia',
            onBack: () {},
            onComplete: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../docs/qa/2026-09-30-onboarding-auth-refresh/430/confirm-name.png',
        ),
      );

      await tester.pumpWidget(
        _app(
          LanguageYouUnderstandScreen(
            initialLanguageCode: 'de',
            onBack: () {},
            onComplete: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../docs/qa/2026-09-30-onboarding-auth-refresh/430/language.png',
        ),
      );
    },
    // These reviewed baselines use macOS font rasterization.
    skip: !Platform.isMacOS,
  );
}
