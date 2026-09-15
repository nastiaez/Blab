import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blab/app/router.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/auth/reset_password_screen.dart';
import 'package:blab/features/auth/widgets/password_strength.dart';
import 'package:blab/main.dart';
import 'package:blab/shared/services/supabase_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('Signed-out app boots into login, not the dev menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BlabApp()));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Blab — dev menu'), findsNothing);
    final BuildContext ctx = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(ctx).colorScheme.primary, BlabColors.brand);
  });

  testWidgets('Debug builds retain explicit dev-menu access', (
    WidgetTester tester,
  ) async {
    blabRouter.go('/dev');
    await tester.pumpWidget(const ProviderScope(child: BlabApp()));
    await tester.pumpAndSettle();
    expect(find.text('Blab — dev menu'), findsOneWidget);
    expect(
      find.textContaining('pair with email', findRichText: true),
      findsNothing,
    );
  });

  test('Password strength estimator covers empty / weak / fair / strong', () {
    expect(estimatePasswordStrength(''), PasswordStrength.empty);
    expect(estimatePasswordStrength('abc'), PasswordStrength.weak);
    expect(estimatePasswordStrength('abcdefgh'), PasswordStrength.weak);
    // BUG-005 regression: 8-char mixed-case landed in Weak previously.
    expect(estimatePasswordStrength('Abcdefgh'), PasswordStrength.fair);
    expect(estimatePasswordStrength('Abcdefg1'), PasswordStrength.fair);
    expect(estimatePasswordStrength('Abcdef1!23'), PasswordStrength.strong);
  });

  test(
    'password acceptance depends only on the visible six-character rule',
    () {
      expect(meetsPasswordRequirement('abcde'), isFalse);
      expect(meetsPasswordRequirement('abcdef'), isTrue);
      expect(estimatePasswordStrength('abcdef'), PasswordStrength.weak);
    },
  );

  testWidgets('reset password puts the minimum rule beside the field', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ResetPasswordScreen())),
    );

    expect(find.text('At least 6 characters'), findsOneWidget);
    expect(find.textContaining("Pick something you'll remember"), findsNothing);

    final fieldBottom = tester.getRect(find.byType(TextField).first).bottom;
    final hintTop = tester.getRect(find.text('At least 6 characters')).top;
    expect(hintTop - fieldBottom, closeTo(6, 0.01));

    await tester.enterText(find.byType(TextField).first, 'abcdef');
    await tester.pump();
    expect(find.text('At least 6 characters'), findsNothing);
    expect(find.text('Weak'), findsOneWidget);
    final strengthTop = tester.getRect(find.text('Weak')).top;
    expect(strengthTop - fieldBottom, closeTo(6, 0.01));
  });

  test('revoked refresh-token failures are recognized for local recovery', () {
    expect(
      SupabaseAuthService.isRevokedSessionError(
        const AuthException('Invalid Refresh Token: Refresh Token Not Found'),
      ),
      isTrue,
    );
    expect(
      SupabaseAuthService.isRevokedSessionError(
        const AuthException('Invalid login credentials'),
      ),
      isFalse,
    );
  });

  test('Supabase auth errors map stable codes to actionable messages', () {
    expect(
      SupabaseAuthService.messageFor(
        AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      ),
      'Email or password is incorrect',
    );
    expect(
      SupabaseAuthService.messageFor(
        AuthApiException(
          'Email address is invalid',
          statusCode: '400',
          code: 'email_address_invalid',
        ),
      ),
      'Enter a valid email address',
    );
    expect(
      SupabaseAuthService.messageFor(
        AuthApiException(
          'For security purposes, you can only request this after 60 seconds.',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        ),
      ),
      'Too many attempts. Try again later.',
    );
  });
}
