import 'package:blab/app/theme.dart';
import 'package:blab/features/onboarding/learn_in_context_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  required VoidCallback onContinue,
  bool reducedMotion = false,
  TextScaler textScaler = TextScaler.noScaling,
  Future<void> Function(String)? onLanguage,
  Future<void> Function()? onPlayAudio,
  Future<void> Function()? onStopAudio,
}) {
  return MaterialApp(
    theme: blabTheme,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: reducedMotion, textScaler: textScaler),
      child: child!,
    ),
    home: LearnInContextScreen(
      interfaceLanguageCode: 'en',
      onBack: () {},
      onContinue: onContinue,
      onChangeInterfaceLanguage: onLanguage ?? (_) async {},
      onPlayAudio: onPlayAudio ?? () async {},
      onStopAudio: onStopAudio ?? () async {},
    ),
  );
}

void main() {
  testWidgets('renders the approved content and Continue never waits', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(_app(onContinue: () => calls++));

    expect(
      find.text('Learn words in context. Build natural sentences'),
      findsOneWidget,
    );
    expect(find.text('You’re learning English'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    expect(calls, 1);
  });

  testWidgets('reduced motion renders corrected messages and popup once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(onContinue: () {}, reducedMotion: true));

    expect(find.byKey(const Key('learning-outgoing-message')), findsOneWidget);
    expect(find.byKey(const Key('learning-incoming-message')), findsOneWidget);
    expect(find.byKey(const Key('vocabulary-popup')), findsOneWidget);
    expect(find.text('exquisite'), findsNWidgets(2));
    expect(find.text('vorzüglich'), findsOneWidget);

    final popupSize = tester.getSize(find.byKey(const Key('vocabulary-popup')));
    expect(popupSize.width, 160);
    expect(
      popupSize.height,
      lessThan(200),
      reason: 'The vocabulary popup must remain a compact anchored card.',
    );
    final popupRect = tester.getRect(find.byKey(const Key('vocabulary-popup')));
    final anchorRect = tester.getRect(
      find.byKey(const Key('vocabulary-anchor')),
    );
    expect(popupRect.bottom, lessThanOrEqualTo(anchorRect.top - 9));
  });

  testWidgets('200% text keeps the vocabulary popup below the status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        onContinue: () {},
        reducedMotion: true,
        textScaler: const TextScaler.linear(2),
      ),
    );

    final popupRect = tester.getRect(find.byKey(const Key('vocabulary-popup')));
    final anchorRect = tester.getRect(
      find.byKey(const Key('vocabulary-anchor')),
    );
    final statusRect = tester.getRect(find.text('You’re learning English'));

    expect(popupRect.left, greaterThanOrEqualTo(12));
    expect(popupRect.right, lessThanOrEqualTo(418));
    expect(popupRect.top, greaterThanOrEqualTo(statusRect.bottom));
    expect(popupRect.bottom, lessThanOrEqualTo(anchorRect.top - 9));
  });

  testWidgets('language control changes the interface language', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      _app(
        onContinue: () {},
        reducedMotion: true,
        onLanguage: (value) async => selected = value,
      ),
    );

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();

    expect(selected, 'de');
  });

  testWidgets('audio failure is non-blocking and route disposal stops speech', (
    tester,
  ) async {
    var stops = 0;
    await tester.pumpWidget(
      _app(
        onContinue: () {},
        reducedMotion: true,
        onPlayAudio: () async => throw StateError('tts unavailable'),
        onStopAudio: () async => stops++,
      ),
    );

    final audioButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const Key('vocabulary-popup')),
        matching: find.byType(IconButton),
      ),
    );
    audioButton.onPressed!();
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(stops, 1);
  });
}
