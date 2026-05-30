import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blab/app/theme.dart';
import 'package:blab/features/auth/widgets/password_strength.dart';
import 'package:blab/main.dart';

void main() {
  testWidgets('App boots into dev menu', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BlabApp()));
    await tester.pumpAndSettle();
    expect(find.text('Blab — dev menu'), findsOneWidget);
    final BuildContext ctx = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(ctx).colorScheme.primary, BlabColors.brand);
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
}
