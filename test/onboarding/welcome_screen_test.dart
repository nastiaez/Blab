import 'package:blab/app/theme.dart';
import 'package:blab/features/onboarding/welcome_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({required VoidCallback onContinue}) {
  return MaterialApp(
    theme: blabTheme,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: WelcomeScreen(
      interfaceLanguageCode: 'en',
      onContinue: onContinue,
      onChangeInterfaceLanguage: (_) async {},
    ),
  );
}

void main() {
  testWidgets('renders the approved Welcome composition at 430 x 932', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(onContinue: () {}));

    expect(
      find.text('Turn chats with friends into language practice'),
      findsOneWidget,
    );
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(
      find.byKey(const Key('welcome-reading-nook-illustration')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.text('Turn chats with friends into language practice'),
          )
          .textAlign,
      TextAlign.center,
    );

    final languageCenter = tester.getCenter(find.text('EN'));
    expect(
      languageCenter.dx,
      greaterThan(360),
      reason: 'The interface-language control must stay right-aligned.',
    );

    final button = tester.getSize(find.byKey(const Key('primary-action')));
    expect(button.height, 56);
  });

  testWidgets('Continue advances immediately', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_app(onContinue: () => calls++));

    await tester.tap(find.text('Continue'));
    expect(calls, 1);
  });
}
