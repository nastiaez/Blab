import 'package:blab/features/auth/forgot_password_sent_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('password reset confirmation uses the mailbox illustration', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const ForgotPasswordSentScreen(email: 'bob@blab.test'),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/onboarding/mailbox-pixel-transparent.png',
      ),
      findsOneWidget,
    );
    expect(find.text('📬'), findsNothing);
  });

  testWidgets('resend starts a visible cooldown without duplicate sends', (
    tester,
  ) async {
    var sends = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: ForgotPasswordSentScreen(
            email: 'bob@blab.test',
            onResend: () async => sends++,
            onChangeEmail: () {},
            onBackToLogin: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Send again'));
    await tester.pump();

    expect(sends, 1);
    expect(find.text('Send again in 30s'), findsOneWidget);
  });
}
