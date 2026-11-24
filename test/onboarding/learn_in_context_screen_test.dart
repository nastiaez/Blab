import 'package:blab/app/theme.dart';
import 'package:blab/features/onboarding/learn_in_context_screen.dart';
import 'package:blab/features/onboarding/widgets/onboarding_top_bar.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app({
  bool reduced = false,
  double scale = 1,
  VoidCallback? onContinue,
  VoidCallback? onBack,
}) => MaterialApp(
  theme: blabTheme,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: reduced,
      textScaler: TextScaler.linear(scale),
    ),
    child: child!,
  ),
  home: LearnInContextScreen(
    interfaceLanguageCode: 'en',
    onBack: onBack ?? () {},
    onContinue: onContinue ?? () {},
    onChangeInterfaceLanguage: (_) async {},
    onPlayAudio: () async {},
    onStopAudio: () async {},
  ),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/deep_dive/Roboto-Variable.ttf'));
    await loader.load();
  });
  testWidgets(
    'Paper phone, real mode toggle, composer and no withdrawn chrome at every stage',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app());
      for (var t = 0; t < 14000; t += 250) {
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byType(OnboardingTopBar), findsNothing);
        expect(find.text('EN'), findsNothing);
        expect(find.byKey(const Key('vocabulary-popup')), findsNothing);
        expect(find.byKey(const Key('vocabulary-anchor')), findsNothing);
        expect(find.text('vorzüglich'), findsNothing);
        for (final key in [
          'demo1-phone-frame',
          'demo1-chat-header',
          'demo1-composer',
          'demo1-send',
          'mode-toggle',
        ]) {
          expect(find.byKey(Key(key)), findsOneWidget);
        }
        expect(find.text('Bestie'), findsOneWidget);
        expect(find.text('Practice'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'English draft types in composer then clears into German sent bubble',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pump(const Duration(milliseconds: 10000));
      expect(find.text('I’m looking forward to it!'), findsOneWidget);
      expect(find.byKey(const Key('demo1-sent-translation')), findsNothing);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('I’m looking forward to it!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('I’m looking forward to it!'), findsNothing);
      expect(find.text('Ich freue mich darauf!'), findsOneWidget);
      expect(
        find.byKey(const Key('learning-incoming-message')),
        findsOneWidget,
      );
    },
  );
  testWidgets('hold pauses draft and release resumes same position', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 8600));
    final before = tester
        .widget<Text>(find.byKey(const Key('demo1-draft')))
        .data;
    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('demo1-composer'))),
    );
    await tester.pump(const Duration(seconds: 4));
    expect(
      tester.widget<Text>(find.byKey(const Key('demo1-draft'))).data,
      before,
    );
    await hold.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester.widget<Text>(find.byKey(const Key('demo1-draft'))).data,
      isNot(before),
    );
  });
  testWidgets('reduced motion stays at final three-message state', (
    tester,
  ) async {
    await tester.pumpWidget(app(reduced: true));
    expect(find.byKey(const Key('demo1-sent-translation')), findsOneWidget);
    expect(find.byKey(const Key('vocabulary-popup')), findsNothing);
    await tester.pump(const Duration(seconds: 20));
    expect(find.byKey(const Key('demo1-sent-translation')), findsOneWidget);
  });
  testWidgets('Back and Continue never wait for teaching sequence', (
    tester,
  ) async {
    var continued = 0, back = 0;
    await tester.pumpWidget(
      app(onContinue: () => continued++, onBack: () => back++),
    );
    await tester.tap(find.text('Continue'));
    await tester.tap(find.byTooltip('Back'));
    expect(continued, 1);
    expect(back, 1);
  });
  testWidgets('360 390 430 and 200 percent remain reachable without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [360.0, 390.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = Size(width, 844);
        await tester.pumpWidget(app(reduced: true, scale: scale));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(const Key('demo1-composer')));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Continue').hitTestable(), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    }
  });
}
