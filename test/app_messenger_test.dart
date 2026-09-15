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
              key: const Key('show-success'),
              onPressed: () => showAppSuccessSnack('Password updated'),
              child: const Text('Show success'),
            ),
            TextButton(
              key: const Key('show-success-above-control'),
              onPressed: () =>
                  showAppSuccessSnack('Alice unblocked', bottomClearance: 64),
              child: const Text('Show success above control'),
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
  test(
    'password success copy has no textual checkmark in launch locales',
    () async {
      for (final locale in const [
        Locale('en'),
        Locale('de'),
        Locale('es'),
        Locale('uk'),
      ]) {
        final l10n = await AppLocalizations.delegate.load(locale);
        expect(l10n.passwordUpdated, isNotEmpty);
        expect(l10n.passwordUpdated, isNot(contains('✓')));
      }
    },
  );

  test('email success copy is localized without a textual checkmark', () async {
    final messages = <String>[];
    for (final locale in const [
      Locale('en'),
      Locale('de'),
      Locale('es'),
      Locale('uk'),
    ]) {
      final l10n = await AppLocalizations.delegate.load(locale);
      messages.add(l10n.emailChanged);
      expect(l10n.emailChanged, isNotEmpty);
      expect(l10n.emailChanged, isNot(contains('✓')));
    }
    expect(messages.toSet(), hasLength(4));
  });

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

  testWidgets('passive success is a compact icon-first pill without close', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());

    await tester.tap(find.byKey(const Key('show-success')));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.duration, passiveAppSnackDuration);
    expect(snackBar.showCloseIcon, isFalse);
    expect(snackBar.backgroundColor, Colors.transparent);
    expect(snackBar.elevation, 0);
    expect(find.byKey(const Key('app-success-icon')), findsOneWidget);
    expect(find.text('Password updated'), findsOneWidget);
    expect(find.textContaining('✓'), findsNothing);
  });

  testWidgets('passive success keeps 12 px above the active bottom surface', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());

    await tester.tap(find.byKey(const Key('show-success-above-control')));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.margin, const EdgeInsets.fromLTRB(16, 0, 16, 76));
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

  testWidgets('opening the email callback route alone does not show success', (
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

    blabRouter.go('/auth/email-changed');
    await tester.pump();
    await tester.pump();

    expect(find.text('Email changed'), findsNothing);
    expect(find.byKey(const Key('app-success-icon')), findsNothing);
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

  testWidgets('route dismissal is safe while the navigator is rebuilding', (
    tester,
  ) async {
    var simulateRouteChange = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: blabTheme,
        scaffoldMessengerKey: appMessengerKey,
        navigatorObservers: [appSnackRouteObserver],
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              if (simulateRouteChange) {
                appSnackRouteObserver.didPop(
                  MaterialPageRoute<void>(builder: (_) => const SizedBox()),
                  null,
                );
              }
              return TextButton(
                onPressed: () {
                  showAppSnack('Saved');
                  setState(() {
                    simulateRouteChange = true;
                  });
                },
                child: const Text('Trigger'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('feedback shown after navigation survives deferred dismissal', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());

    appSnackRouteObserver.didPop(
      MaterialPageRoute<void>(builder: (_) => const SizedBox()),
      null,
    );
    showAppSnack('Saved after navigation');
    await tester.pump();

    expect(find.text('Saved after navigation'), findsOneWidget);
  });

  testWidgets('destination success waits for navigation scheduled next frame', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());

    showAppSuccessSnackAfterNavigation('Email changed');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appSnackRouteObserver.didPop(
        MaterialPageRoute<void>(builder: (_) => const SizedBox()),
        null,
      );
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('Email changed'), findsOneWidget);
    expect(find.byKey(const Key('app-success-icon')), findsOneWidget);
  });
}
