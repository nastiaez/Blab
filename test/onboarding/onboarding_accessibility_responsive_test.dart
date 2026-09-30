import 'package:blab/app/theme.dart';
import 'package:blab/features/auth/auth_screen.dart';
import 'package:blab/features/auth/forgot_password_screen.dart';
import 'package:blab/features/auth/forgot_password_sent_screen.dart';
import 'package:blab/features/auth/reset_password_screen.dart';
import 'package:blab/features/onboarding/auth/auth_method_screen.dart';
import 'package:blab/features/onboarding/auth/email_auth_screen.dart';
import 'package:blab/features/onboarding/auth/reset_link_invalid_screen.dart';
import 'package:blab/features/onboarding/confirm_name_screen.dart';
import 'package:blab/features/onboarding/language_you_understand_screen.dart';
import 'package:blab/features/onboarding/learn_in_context_screen.dart';
import 'package:blab/features/onboarding/welcome_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {required String localeCode, double textScale = 1}) {
  return ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: blabTheme,
      locale: Locale(localeCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, content) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: content!,
      ),
      home: child,
    ),
  );
}

void main() {
  testWidgets(
    'all canonical screens avoid overflow at both target sizes and 100/200% text in German and Ukrainian',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final screens = <(String, Widget Function())>[
        (
          'welcome',
          () => WelcomeScreen(
            interfaceLanguageCode: 'de',
            onContinue: () {},
            onChangeInterfaceLanguage: (_) async {},
          ),
        ),
        (
          'learn',
          () => LearnInContextScreen(
            interfaceLanguageCode: 'de',
            onBack: () {},
            onContinue: () {},
            onChangeInterfaceLanguage: (_) async {},
            onPlayAudio: () async {},
            onStopAudio: () async {},
          ),
        ),
        (
          'signup method',
          () => AuthMethodScreen(
            mode: AuthMode.signUp,
            interfaceLanguageCode: 'de',
            onBack: () {},
            onGoogle: () async {},
            onEmail: () {},
            onSwitchMode: () {},
            onChangeInterfaceLanguage: (_) async {},
            onTerms: () {},
            onPrivacy: () {},
          ),
        ),
        (
          'signup email',
          () => EmailAuthScreen(
            mode: AuthMode.signUp,
            onBack: () {},
            onAuthenticated: () async {},
            onForgotPassword: (_) {},
            onExistingAccount: (_) {},
          ),
        ),
        (
          'login method',
          () => AuthMethodScreen(
            mode: AuthMode.logIn,
            interfaceLanguageCode: 'de',
            onBack: () {},
            onGoogle: () async {},
            onEmail: () {},
            onSwitchMode: () {},
            onChangeInterfaceLanguage: (_) async {},
            onTerms: () {},
            onPrivacy: () {},
          ),
        ),
        (
          'login email',
          () => EmailAuthScreen(
            mode: AuthMode.logIn,
            onBack: () {},
            onAuthenticated: () async {},
            onForgotPassword: (_) {},
            onExistingAccount: (_) {},
          ),
        ),
        (
          'reset request',
          () => const ForgotPasswordScreen(
            prefilledEmail: 'lange.adresse@example.com',
          ),
        ),
        (
          'check email',
          () => ForgotPasswordSentScreen(
            email: 'lange.adresse@example.com',
            onResend: () async {},
            onChangeEmail: () {},
            onBackToLogin: () {},
          ),
        ),
        ('new password', () => const ResetPasswordScreen()),
        (
          'invalid reset link',
          () => ResetLinkInvalidScreen(
            onRequestNewLink: () {},
            onBackToLogin: () {},
          ),
        ),
        (
          'confirm name',
          () => ConfirmNameScreen(
            initialName: 'Alexandria Example',
            onBack: () {},
            onComplete: () {},
          ),
        ),
        (
          'language',
          () => LanguageYouUnderstandScreen(
            initialLanguageCode: 'de',
            onBack: () {},
            onComplete: () {},
          ),
        ),
      ];

      final failures = <String>[];
      for (final size in [const Size(370, 800), const Size(430, 932)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        for (final textScale in [1.0, 2.0]) {
          for (final localeCode in ['de', 'uk']) {
            for (final screen in screens) {
              await tester.pumpWidget(
                _app(screen.$2(), localeCode: localeCode, textScale: textScale),
              );
              await tester.pump();
              final exception = tester.takeException();
              if (exception != null) {
                failures.add(
                  '${screen.$1} ($localeCode, ${size.width.toInt()}x${size.height.toInt()}, ${textScale}x): $exception',
                );
              }
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
            }
          }
        }
      }

      expect(failures, isEmpty, reason: failures.join('\n'));
    },
  );

  testWidgets('large-text form titles wrap instead of truncating', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(370, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        LanguageYouUnderstandScreen(onBack: () {}, onComplete: () {}),
        localeCode: 'uk',
        textScale: 2,
      ),
    );

    final title = tester.widget<Text>(find.text('Мова, яку ти розумієш'));
    expect(title.maxLines, greaterThanOrEqualTo(2));
    expect(title.overflow, isNot(TextOverflow.ellipsis));
  });

  testWidgets('TalkBack labels follow the active interface language', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _app(
        WelcomeScreen(
          interfaceLanguageCode: 'uk',
          onContinue: () {},
          onChangeInterfaceLanguage: (_) async {},
        ),
        localeCode: 'uk',
      ),
    );

    expect(find.bySemanticsLabel('Мова інтерфейсу'), findsOneWidget);
    expect(find.bySemanticsLabel('Interface language'), findsNothing);

    await tester.pumpWidget(
      _app(
        LearnInContextScreen(
          interfaceLanguageCode: 'de',
          onBack: () {},
          onContinue: () {},
          onChangeInterfaceLanguage: (_) async {},
          onPlayAudio: () async {},
          onStopAudio: () async {},
        ),
        localeCode: 'de',
      ),
    );

    expect(find.text('Du lernst Englisch'), findsOneWidget);
    expect(find.byTooltip('Anhören: exquisite'), findsOneWidget);
    semantics.dispose();
  });
}
