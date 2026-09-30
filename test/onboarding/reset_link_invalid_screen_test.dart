import 'package:blab/app/theme.dart';
import 'package:blab/features/onboarding/auth/reset_link_invalid_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('expired recovery links offer a safe new request', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: blabTheme,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: ResetLinkInvalidScreen(
          onRequestNewLink: () => requests++,
          onBackToLogin: () {},
        ),
      ),
    );

    expect(find.text('Reset link expired'), findsOneWidget);
    expect(find.text('Request a new link'), findsOneWidget);
    expect(find.byKey(const Key('recovery-mailbox')), findsOneWidget);

    await tester.tap(find.text('Request a new link'));
    expect(requests, 1);
  });
}
