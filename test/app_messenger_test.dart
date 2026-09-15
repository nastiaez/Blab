import 'package:blab/app/app_messenger.dart';
import 'package:blab/app/router.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _testApp() {
  return MaterialApp(
    theme: blabTheme,
    scaffoldMessengerKey: appMessengerKey,
    home: Scaffold(
      body: Builder(
        builder: (context) => Column(
          children: [
            TextButton(
              key: const Key('show-passive'),
              onPressed: () => showAppSnack('Saved'),
              child: const Text('Show passive'),
            ),
            TextButton(
              key: const Key('show-actionable'),
              onPressed: () => showAppSnack(
                'Language changed',
                action: SnackBarAction(label: 'Undo', onPressed: () {}),
              ),
              child: const Text('Show actionable'),
            ),
            TextButton(
              key: const Key('other-action'),
              onPressed: () {},
              child: const Text('Other action'),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('passive feedback stays for 2.5 seconds without a close icon', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());

    await tester.tap(find.byKey(const Key('show-passive')));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.duration, const Duration(milliseconds: 2500));
    expect(blabTheme.snackBarTheme.showCloseIcon, isFalse);
  });

  testWidgets('feedback with an action stays for 4 seconds', (tester) async {
    await tester.pumpWidget(_testApp());

    await tester.tap(find.byKey(const Key('show-actionable')));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.duration, const Duration(seconds: 4));
  });

  testWidgets('an unrelated tap keeps actionable feedback available', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());

    await tester.tap(find.byKey(const Key('show-actionable')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('other-action')));
    await tester.pump();

    expect(find.text('Language changed'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('navigating to another route dismisses visible feedback', (
    tester,
  ) async {
    blabRouter.go('/auth?mode=login');
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: blabTheme,
          scaffoldMessengerKey: appMessengerKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: blabRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();

    showAppSnack(
      'Language changed',
      action: SnackBarAction(label: 'Undo', onPressed: () {}),
    );
    await tester.pump();
    expect(find.text('Language changed'), findsOneWidget);

    blabRouter.go('/auth/forgot');
    await tester.pumpAndSettle();

    expect(find.text('Language changed'), findsNothing);
  });

  testWidgets('going back dismisses visible feedback', (tester) async {
    blabRouter.go('/auth?mode=login');
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: blabTheme,
          scaffoldMessengerKey: appMessengerKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: blabRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();
    blabRouter.push('/auth/forgot');
    await tester.pumpAndSettle();

    showAppSnack(
      'Language changed',
      action: SnackBarAction(label: 'Undo', onPressed: () {}),
    );
    await tester.pump();
    expect(find.text('Language changed'), findsOneWidget);

    blabRouter.pop();
    await tester.pumpAndSettle();

    expect(find.text('Language changed'), findsNothing);
  });
}
