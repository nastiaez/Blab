import 'released125_geometry_fixture.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/onboarding/learn_in_context_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:flutter/services.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('Roboto');
    loader.addFont(
      File(
        'assets/fonts/deep_dive/Roboto-Variable.ttf',
      ).readAsBytes().then((b) => ByteData.sublistView(b)),
    );
    await loader.load();
  });
  for (final size in [
    const Size(360, 780),
    const Size(360, 640),
    const Size(390, 844),
  ]) {
    testWidgets('released geometry and maximal common titles at $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final tops = <double>[];
      final titleSizes = <double>[];
      for (var step = 1; step <= 3; step++) {
        await tester.pumpWidget(
          MaterialApp(
            theme: blabTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Released125Screen(
              key: ValueKey('baseline$step'),
              demoStep: step,
              interfaceLanguageCode: 'en',
              onBack: () {},
              onContinue: () {},
              onChangeInterfaceLanguage: (_) async {},
              onPlayAudio: () async {},
              onStopAudio: () async {},
            ),
          ),
        );
        await tester.pump();
        final baselineFrame = tester.getRect(
          find.byKey(const Key('demo1-phone-frame')),
        );
        final baselineHeading = find
            .byWidgetPredicate(
              (w) => w is Text && w.style?.fontWeight == FontWeight.w800,
            )
            .first;
        final baselineHeadingHeight = tester.getSize(baselineHeading).height;
        final baselineContinue = tester.getRect(find.text('Continue'));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          MaterialApp(
            theme: blabTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LearnInContextScreen(
              key: ValueKey(step),
              demoStep: step,
              interfaceLanguageCode: 'en',
              onBack: () {},
              onContinue: () {},
              onChangeInterfaceLanguage: (_) async {},
              onPlayAudio: () async {},
              onStopAudio: () async {},
            ),
          ),
        );
        await tester.pump();
        final frame = tester.getRect(
          find.byKey(const Key('demo1-phone-frame')),
        );
        tops.add(frame.top);
        expect(frame.size, baselineFrame.size);
        expect(frame.left, baselineFrame.left);
        expect(tester.getRect(find.text('Continue')), baselineContinue);
        final heading = find
            .byWidgetPredicate(
              (w) => w is Text && w.style?.fontWeight == FontWeight.w800,
            )
            .first;
        expect(
          frame.top - baselineFrame.top,
          closeTo(tester.getSize(heading).height - baselineHeadingHeight, .01),
        );
        final text = tester.widget<Text>(heading);
        final style = DefaultTextStyle.of(
          tester.element(heading),
        ).style.merge(text.style);
        final painter = TextPainter(
          text: TextSpan(text: text.data, style: style),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: size.width - 40);
        expect(painter.computeLineMetrics().length, 1);
        painter.dispose();
        titleSizes.add(text.style!.fontSize!);
        expect(text.style!.fontSize!, greaterThan(26));
        final larger = TextPainter(
          text: TextSpan(
            text: 'Make sense of grammar',
            style: style.copyWith(fontSize: text.style!.fontSize! + .05),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        // Maximality is checked against whichever actual glyph run is widest.
        final widths = <double>[];
        for (final title in [
          'Build natural sentences',
          'Learn words in context',
          'Make sense of grammar',
        ]) {
          final m = TextPainter(
            text: TextSpan(
              text: title,
              style: style.copyWith(fontSize: text.style!.fontSize! + .05),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          widths.add(m.width);
          m.dispose();
        }
        if (text.style!.fontSize! < 34) {
          expect(
            widths.reduce((a, b) => a > b ? a : b),
            greaterThan(size.width - 40),
          );
        }
        debugPrint(
          'GLYPHS21905 viewport=$size common=${text.style!.fontSize} widthsAtPlus005=$widths titles=Build-natural,Learn-words,Make-sense',
        );
        larger.dispose();
        if (step > 1) {
          final subtitle = find.text(
            step == 2
                ? 'Long press a message to translate.'
                : 'Explore your sentence with Deep Dive.',
          );
          expect(
            tester.getTopLeft(subtitle).dy - tester.getBottomLeft(heading).dy,
            closeTo(8, .01),
          );
          expect(
            frame.top - tester.getBottomLeft(subtitle).dy,
            closeTo(20, .01),
          );
        }
        expect(frame.width, closeTo(306, .01));
        expect(frame.height, closeTo(584, .01));
        debugPrint(
          'FIT21905 viewport=$size step=$step size=${text.style!.fontSize} frame=$frame',
        );
        expect(tester.takeException(), isNull);
      }
      expect(titleSizes.toSet().length, 1);
      expect(tops[1], closeTo(tops[0], 20.01));
      expect(tops[2], closeTo(tops[0], 20.01));
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('accessible headings retain readable size and scrolling', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (var step = 1; step <= 3; step++) {
      await tester.pumpWidget(
        MaterialApp(
          theme: blabTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.8)),
            child: child!,
          ),
          home: LearnInContextScreen(
            key: ValueKey(step),
            demoStep: step,
            interfaceLanguageCode: 'en',
            onBack: () {},
            onContinue: () {},
            onChangeInterfaceLanguage: (_) async {},
            onPlayAudio: () async {},
            onStopAudio: () async {},
          ),
        ),
      );
      await tester.pump();
      final heading = find
          .byWidgetPredicate(
            (w) => w is Text && w.style?.fontWeight == FontWeight.w800,
          )
          .first;
      expect(tester.widget<Text>(heading).style!.fontSize, 34);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
  for (var step = 1; step <= 3; step++) {
    testWidgets('Demo$step swipe boundaries retain taps and reading holds', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var next = 0, back = 0, skip = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: blabTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LearnInContextScreen(
            demoStep: step,
            interfaceLanguageCode: 'en',
            onBack: () => back++,
            onContinue: () => next++,
            onSkip: () => skip++,
            onChangeInterfaceLanguage: (_) async {},
            onPlayAudio: () async {},
            onStopAudio: () async {},
          ),
        ),
      );
      await tester.pump();
      final target = find.byKey(const Key('learning-animation-hold-target'));
      await tester.tap(target);
      await tester.longPress(target);
      await tester.pump();
      expect([next, back, skip], [0, 0, 0]);
      await tester.drag(target, const Offset(0, -70));
      expect([next, back, skip], [0, 0, 0]);
      await tester.drag(target, const Offset(-140, 0));
      expect(next, step < 3 ? 1 : 0);
      await tester.drag(target, const Offset(140, 0));
      expect(back, step > 1 ? 1 : 0);
      await tester.tap(find.text('Continue'));
      expect(next, step < 3 ? 2 : 1);
      await tester.tap(find.text('Skip'));
      expect(skip, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
