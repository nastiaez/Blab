import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blab/app/router.dart';
import 'package:blab/app/theme.dart';
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
}
