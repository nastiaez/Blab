import 'package:blab/features/auth/forgot_password_sent_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('password reset confirmation uses the mailbox illustration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const ForgotPasswordSentScreen(email: 'bob@blab.test'),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/icons/email-mailbox.png',
      ),
      findsOneWidget,
    );
    expect(find.text('📬'), findsNothing);
  });
}
