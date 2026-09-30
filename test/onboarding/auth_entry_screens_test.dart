import 'package:blab/app/theme.dart';
import 'package:blab/features/auth/auth_screen.dart';
import 'package:blab/features/auth/forgot_password_screen.dart';
import 'package:blab/features/onboarding/auth/email_auth_screen.dart';
import 'package:blab/features/onboarding/auth/auth_method_screen.dart';
import 'package:blab/features/onboarding/onboarding_theme.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {EmailAuthAction? emailAuth}) {
  return ProviderScope(
    overrides: [
      if (emailAuth != null)
        emailAuthActionProvider.overrideWithValue(emailAuth),
    ],
    child: MaterialApp(
      theme: blabTheme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    ),
  );
}

void main() {
  testWidgets('signup method matches the approved choice hierarchy', (
    tester,
  ) async {
    var termsOpened = 0;
    var privacyOpened = 0;
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
          onTerms: () => termsOpened++,
          onPrivacy: () => privacyOpened++,
        ),
      ),
    );

    expect(find.text('Sign up to\nstart learning'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.byKey(const Key('google-auth-icon')), findsOneWidget);
    expect(find.byKey(const Key('email-auth-icon')), findsOneWidget);
    expect(find.text('Already have an account? Log in'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.text('Already have an account? Log in'))
          .style
          ?.decoration,
      isNot(TextDecoration.underline),
    );
    expect(find.textContaining('Terms of Service'), findsOneWidget);

    await tester.tap(find.byKey(const Key('auth-terms-link')));
    await tester.tap(find.byKey(const Key('auth-privacy-link')));
    expect(termsOpened, 1);
    expect(privacyOpened, 1);
  });

  testWidgets('login method exposes the reciprocal signup branch', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        AuthMethodScreen(
          mode: AuthMode.logIn,
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

    expect(find.text('Log in to Blab'), findsOneWidget);
    expect(find.text("Don’t have an account? Sign up"), findsOneWidget);
  });

  testWidgets('auth method language control is functional', (tester) async {
    String? selected;
    await tester.pumpWidget(
      _app(
        AuthMethodScreen(
          mode: AuthMode.signUp,
          interfaceLanguageCode: 'en',
          onBack: () {},
          onGoogle: () async {},
          onEmail: () {},
          onSwitchMode: () {},
          onChangeInterfaceLanguage: (value) async => selected = value,
          onTerms: () {},
          onPrivacy: () {},
        ),
      ),
    );

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();

    expect(selected, 'es');
  });

  testWidgets('email signup collects only email and password', (tester) async {
    EmailAuthRequest? request;
    await tester.pumpWidget(
      _app(
        EmailAuthScreen(
          mode: AuthMode.signUp,
          onBack: () {},
          onAuthenticated: () async {},
          onForgotPassword: (_) {},
          onExistingAccount: (_) {},
        ),
        emailAuth: (value) async {
          request = value;
        },
      ),
    );

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Sign up with email'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'new@blab.test');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(request?.mode, AuthMode.signUp);
    expect(request?.name, isEmpty);
  });

  testWidgets('email auth exposes correct autofill hints and keyboard flow', (
    tester,
  ) async {
    EmailAuthRequest? request;
    await tester.pumpWidget(
      _app(
        EmailAuthScreen(
          mode: AuthMode.signUp,
          onBack: () {},
          onAuthenticated: () async {},
          onForgotPassword: (_) {},
          onExistingAccount: (_) {},
        ),
        emailAuth: (value) async => request = value,
      ),
    );

    final fields = find.byType(TextField);
    final email = tester.widget<TextField>(fields.at(0));
    final password = tester.widget<TextField>(fields.at(1));
    expect(email.autofillHints, const [AutofillHints.email]);
    expect(email.keyboardType, TextInputType.emailAddress);
    expect(email.textInputAction, TextInputAction.next);
    expect(password.autofillHints, const [AutofillHints.newPassword]);
    expect(password.textInputAction, TextInputAction.done);

    await tester.tap(fields.at(0));
    await tester.enterText(fields.at(0), 'new@blab.test');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(password.focusNode?.hasFocus, isTrue);

    await tester.enterText(fields.at(1), 'password123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(request?.email, 'new@blab.test');
  });

  testWidgets('login asks password managers for an existing password', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        EmailAuthScreen(
          mode: AuthMode.logIn,
          onBack: () {},
          onAuthenticated: () async {},
          onForgotPassword: (_) {},
          onExistingAccount: (_) {},
        ),
      ),
    );

    final password = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(password.autofillHints, const [AutofillHints.password]);
  });

  testWidgets('login recovery link is aligned to the leading field edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        EmailAuthScreen(
          mode: AuthMode.logIn,
          onBack: () {},
          onAuthenticated: () async {},
          onForgotPassword: (_) {},
          onExistingAccount: (_) {},
        ),
      ),
    );

    final emailLeft = tester.getTopLeft(find.byType(TextField).first).dx;
    final forgotLeft = tester.getTopLeft(find.text('Forgot password?')).dx;
    expect(forgotLeft, closeTo(emailLeft, 0.1));
  });

  testWidgets('onboarding fields share the softer focused outline', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        EmailAuthScreen(
          mode: AuthMode.logIn,
          onBack: () {},
          onAuthenticated: () async {},
          onForgotPassword: (_) {},
          onExistingAccount: (_) {},
        ),
      ),
    );

    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      final border = field.decoration!.focusedBorder! as OutlineInputBorder;
      expect(border.borderSide.color, OnboardingTheme.actionPressed);
      expect(border.borderSide.width, 1.5);
    }
  });

  testWidgets('recovery request opens with the field in its neutral state', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const ForgotPasswordScreen()));
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isFalse);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus ??
          false,
      isFalse,
    );
  });
}
