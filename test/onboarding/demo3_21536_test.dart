import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/deep_dive_screen.dart';
import 'package:blab/features/onboarding/learn_in_context_screen.dart';
import 'package:blab/features/onboarding/widgets/demo3_phone.dart';
import 'package:blab/features/onboarding/widgets/demo2_phone.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {double scale = 1, bool reduced = false}) =>
    ProviderScope(
      child: MaterialApp(
        theme: blabTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
        home: Scaffold(body: Center(child: child)),
      ),
    );
void main() {
  testWidgets(
    'exact approved text; no word definitions, wrong sentence or loading',
    (t) async {
      await t.pumpWidget(
        host(
          SizedBox(
            width: 306,
            height: 468,
            child: Demo3Phone(
              milliseconds: 11000,
              reduced: false,
              large: false,
            ),
          ),
        ),
      );
      await t.pump();
      await t.pump();
      expect(find.text(demo3Rule), findsOneWidget);
      expect(find.byType(DeepDiveScreen), findsOneWidget);
      expect(find.text(demo3English), findsNothing);
      expect(find.text('WHY THIS MISTAKE?'), findsOneWidget);
      expect(find.text('Word order'), findsOneWidget);
      await t.tap(find.byTooltip('Translate'));
      await t.pump();
      expect(find.text(demo3English), findsOneWidget);
      expect(find.text(demo3Rule), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await t.tap(find.byKey(const Key('demo3-close')));
      await t.pump();
      expect(find.text(demo3Rule), findsNothing);
    },
  );
  testWidgets(
    '21558 blue held indicators, persistent frame, matching correction spans',
    (t) async {
      for (final ms in [2600, 3000, 3800, 5000, 7500, 11000, 17000, 19000]) {
        await t.pumpWidget(
          host(
            SizedBox(
              width: 306,
              height: 468,
              child: Demo3Phone(
                key: ValueKey(ms),
                milliseconds: ms,
                reduced: false,
                large: false,
              ),
            ),
          ),
        );
        await t.pump();
        await t.pump();
        final outline = find.byKey(const Key('demo3-phone-outline'));
        expect(outline, findsOneWidget);
        expect(t.getSize(outline), const Size(306, 468));
        final border =
            t.widget<DecoratedBox>(outline).decoration as BoxDecoration;
        expect(border.borderRadius, BorderRadius.circular(26));
        if ([2600, 3000, 3800, 7500, 17000].contains(ms)) {
          final dot = t.widget<Container>(
            find.byKey(const Key('demo3-blue-touch-dot')),
          );
          final paint = dot.decoration! as BoxDecoration;
          expect(paint.color, const Color(0xFFA0C1FE));
          expect(paint.shape, BoxShape.circle);
          expect(paint.border, isNull);
          expect(paint.boxShadow, isNull);
        } else {
          expect(find.byKey(const Key('demo3-blue-touch-dot')), findsNothing);
        }
        if (ms == 11000) {
          final screen = t.widget<DeepDiveScreen>(find.byType(DeepDiveScreen));
          expect(
            screen.segments!.where((s) => s.struck).single.text,
            'wir kochen',
          );
          expect(
            screen.segments!.where((s) => s.corrected).single.text,
            'kochen wir',
          );
          final spans = <TextSpan>[];
          void visit(InlineSpan span) {
            if (span is TextSpan) {
              spans.add(span);
              for (final child in span.children ?? <InlineSpan>[]) {
                visit(child);
              }
            }
          }

          for (final rich in t.widgetList<RichText>(find.byType(RichText))) {
            visit(rich.text);
          }
          expect(
            spans.any(
              (s) =>
                  s.text == 'wir' &&
                  s.style?.decoration == TextDecoration.lineThrough,
            ),
            isTrue,
          );
          expect(
            spans.any(
              (s) =>
                  s.text == 'kochen' && s.style?.fontWeight == FontWeight.w700,
            ),
            isTrue,
          );
          expect(find.text(demo3Rule), findsOneWidget);
        }
        expect(t.takeException(), isNull);
      }
    },
  );
  testWidgets(
    '21565 compact embedding gaps only; original defaults and touch targets retained',
    (t) async {
      await t.pumpWidget(
        host(
          const SizedBox(
            width: 306,
            height: 468,
            child: Demo3Phone(
              milliseconds: 11000,
              reduced: false,
              large: false,
            ),
          ),
        ),
      );
      await t.pump();
      await t.pump();
      final page = find.byType(DeepDiveScreen);
      final scroll = t.widget<SingleChildScrollView>(
        find.descendant(of: page, matching: find.byType(SingleChildScrollView)),
      );
      expect(scroll.padding, const EdgeInsets.fromLTRB(24, 16, 24, 24));
      expect(
        t
            .widget<SizedBox>(
              find.byKey(const Key('deep-dive-message-actions-gap')),
            )
            .height,
        12,
      );
      expect(
        t
            .widget<SizedBox>(
              find.byKey(const Key('deep-dive-actions-lesson-gap')),
            )
            .height,
        12,
      );
      final translate = find
          .descendant(of: page, matching: find.byType(IconButton))
          .last;
      expect(t.getSize(translate).height, 48);
      for (final lesson in <DeepDiveLesson?>[
        null,
        DeepDiveLesson(
          heading: 'Word order',
          explanation: demo3Rule,
          onBack: () {},
        ),
      ]) {
        await t.pumpWidget(
          host(
            DeepDiveScreen(
              key: UniqueKey(),
              messageId: 'spacing-default',
              authoredText: demo3German,
              displayText: demo3German,
              learningLanguageCode: 'de',
              knownLanguageCode: 'en',
              aidsEnabled: true,
              wordLookupEnabled: false,
              lesson: lesson,
            ),
          ),
        );
        await t.pump();
        final scroll = t.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        expect(scroll.padding, const EdgeInsets.all(24));
        expect(
          t
              .widget<SizedBox>(
                find.byKey(const Key('deep-dive-message-actions-gap')),
              )
              .height,
          20,
        );
        if (lesson != null) {
          expect(
            t
                .widget<SizedBox>(
                  find.byKey(const Key('deep-dive-actions-lesson-gap')),
                )
                .height,
            20,
          );
        }
        expect(t.takeException(), isNull);
      }
    },
  );
  testWidgets('two cycles across sizes, text scales and phases', (t) async {
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    for (final width in [360.0, 390.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        t.view.physicalSize = Size(width, 844);
        for (final ms in [
          0,
          3000,
          5000,
          7500,
          11000,
          17000,
          19000,
          0,
          5000,
          11000,
        ]) {
          await t.pumpWidget(
            host(
              SizedBox(
                width: 306,
                height: scale > 1 ? 700 : 468,
                child: Demo3Phone(
                  key: ValueKey('$width/$scale/$ms'),
                  milliseconds: ms,
                  reduced: false,
                  large: scale > 1,
                ),
              ),
              scale: scale,
            ),
          );
          await t.pump();
          await t.pump();
          expect(t.takeException(), isNull, reason: '$width/$scale/$ms');
          if (ms == 5000) {
            expect(find.text('Deep Dive'), findsOneWidget);
            expect(find.byType(Demo2MessagePanels), findsOneWidget);
          }
          if (ms == 11000) expect(find.text(demo3Rule), findsOneWidget);
        }
      }
    }
  });
  testWidgets(
    'own-message long press opens actual menu; Deep Dive opens rule',
    (t) async {
      await t.pumpWidget(
        host(
          const SizedBox(
            width: 306,
            height: 468,
            child: Demo3Phone(milliseconds: 0, reduced: false, large: false),
          ),
        ),
      );
      await t.pump();
      await t.pump();
      await t.longPress(find.byKey(const Key('learning-outgoing-message')));
      await t.pump();
      await t.pump();
      final message = t.getRect(
        find.byKey(const Key('learning-outgoing-message')),
      );
      final reactions = t.getRect(
        find.byKey(const Key('demo2-scaled-reactions')),
      );
      final actions = t.getRect(find.byKey(const Key('demo2-scaled-actions')));
      expect(reactions.bottom, lessThanOrEqualTo(message.top - 7));
      expect(actions.top, greaterThanOrEqualTo(message.bottom + 7));
      await t.tap(find.byKey(const ValueKey('message-action-deepDive')));
      await t.pump();
      await t.pump();
      expect(find.text(demo3Rule), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
  testWidgets('third title subtitle and reduced motion rule', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(390, 844);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(
      host(
        LearnInContextScreen(
          demoStep: 3,
          interfaceLanguageCode: 'en',
          onBack: () {},
          onContinue: () {},
          onChangeInterfaceLanguage: (_) async {},
          onPlayAudio: () async {},
          onStopAudio: () async {},
        ),
        reduced: true,
      ),
    );
    await t.pump();
    await t.pump();
    expect(find.text('Make sense of grammar'), findsOneWidget);
    expect(find.text('Explore your sentence with Deep Dive.'), findsOneWidget);
    expect(find.text(demo3Rule), findsOneWidget);
  });
}
