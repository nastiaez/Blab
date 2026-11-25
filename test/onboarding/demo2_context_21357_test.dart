import 'dart:math' as math;
import 'package:blab/app/theme.dart';
import 'package:blab/features/onboarding/learn_in_context_screen.dart';
import 'package:blab/features/onboarding/widgets/demo2_phone.dart';
import 'package:blab/features/chat/message_actions.dart';
import 'package:blab/features/chat/widgets/message_action_row.dart';
import 'package:blab/features/chat/widgets/floating_reaction_row.dart';
import 'package:blab/features/chat/widgets/message_learning_content.dart';
import 'package:blab/features/chat/widgets/message_bubble_surface.dart';
import 'package:blab/features/chat/chat_screen.dart' show MessageStatusNotice;
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app({
  double scale = 1,
  bool reduced = false,
  VoidCallback? back,
  VoidCallback? next,
  VoidCallback? skip,
}) => ProviderScope(
  child: MaterialApp(
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
      demoStep: 2,
      interfaceLanguageCode: 'en',
      onBack: back ?? () {},
      onContinue: next ?? () {},
      onSkip: skip ?? () {},
      onChangeInterfaceLanguage: (_) async {},
      onPlayAudio: () async {},
      onStopAudio: () async {},
    ),
  ),
);
Future<void> frames(WidgetTester t, [int ms = 200]) async {
  await t.pump(Duration(microseconds: ms * 900));
  await t.pump();
  await t.pump();
}

Rect visualRect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/deep_dive/Roboto-Variable.ttf'));
    await loader.load();
  });
  testWidgets(
    'production menu default retains Reply Copy and BOTH reporting actions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: blabTheme,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: MessageActionRow(
              message: demo2Bestie,
              mode: ChatMode.practice,
              canTranslate: true,
              canListen: true,
              canDeepDive: true,
              onAction: (_) {},
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<MessageActionRow>(find.byType(MessageActionRow))
            .visibleActions,
        isNull,
      );
      for (final action in [
        MessageAction.translate,
        MessageAction.listen,
        MessageAction.deepDive,
        MessageAction.reply,
        MessageAction.copy,
        MessageAction.reportTranslation,
        MessageAction.report,
      ]) {
        expect(
          find.byKey(ValueKey('message-action-${action.name}')),
          findsOneWidget,
        );
      }
    },
  );
  testWidgets(
    'every menu/select boundary preserves readable selected message and nonoverlapping panels',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [360.0, 390.0, 430.0]) {
        for (final scale in [1.0, 2.0]) {
          for (final ms in [3900, 4500, 6999, 7000, 7500, 7990]) {
            tester.view.physicalSize = Size(width, 844);
            await tester.pumpWidget(app(scale: scale));
            await frames(tester, ms);
            await tester.pump();
            await tester.pump();
            final b = visualRect(
                  tester,
                  find.byKey(const Key('learning-incoming-message')),
                ),
                r = visualRect(tester, find.byType(FloatingReactionRow)),
                a = visualRect(tester, find.byType(MessageActionRow));
            expect(
              r.width,
              closeTo(kFloatingReactionRowWidth * demo2PanelScale, 0.01),
            );
            expect(
              r.height,
              closeTo(kFloatingReactionRowHeight * demo2PanelScale, 0.01),
            );
            expect(a.width, closeTo(202 * demo2PanelScale, 0.01));
            expect(b.overlaps(r), isFalse);
            expect(b.overlaps(a), isFalse);
            expect(b.top - r.bottom, closeTo(8, 0.01));
            expect(a.top - b.bottom, closeTo(8, 0.01));
            expect(b.top, greaterThanOrEqualTo(68));
            expect(b.bottom, lessThan(780));
            expect(a.bottom, lessThan(780));
            expect(r.top, greaterThanOrEqualTo(68));
            expect(
              find.byKey(const ValueKey('message-action-reply')),
              findsNothing,
            );
            expect(
              find.byKey(const ValueKey('message-action-copy')),
              findsNothing,
            );
            expect(
              find.byKey(const ValueKey('message-action-report')),
              findsNothing,
            );
            expect(
              find.byKey(const ValueKey('message-action-reportTranslation')),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    },
  );
  test(
    'timeline has reading pause, long hold, real menu, Translate tap and final hold',
    () {
      expect(demo2PhaseAt(0), Demo2Phase.conversation);
      expect(demo2PhaseAt(3000), Demo2Phase.pressHold);
      expect(demo2PhaseAt(5000), Demo2Phase.menu);
      expect(demo2PhaseAt(7500), Demo2Phase.translateTap);
      expect(demo2PhaseAt(11000), Demo2Phase.translated);
    },
  );
  testWidgets(
    'exact header and second dot; sequence shows actual emoji/menu then real secondary lane',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(app());
      await frames(tester);
      expect(find.text('Learn words in context'), findsOneWidget);
      expect(find.text('Long press a message to translate.'), findsOneWidget);
      final active = tester.widget<Container>(
        find.byKey(const ValueKey('demo-progress-dot-1')),
      );
      expect((active.decoration! as BoxDecoration).color, BlabColors.brand);
      expect(find.byType(MessageLearningContent), findsOneWidget);
      expect(find.text(demo2English), findsNothing);
      await frames(tester, 2800);
      expect(find.byKey(const Key('demo2-long-press')), findsOneWidget);
      await frames(tester, 2000);
      expect(find.byType(MessageActionRow), findsOneWidget);
      expect(find.byType(FloatingReactionRow), findsOneWidget);
      for (final emoji in kQuickMessageReactions) {
        expect(find.text(emoji), findsOneWidget);
      }
      for (final action in [
        MessageAction.translate,
        MessageAction.listen,
        MessageAction.deepDive,
      ]) {
        expect(
          find.byKey(ValueKey('message-action-${action.name}')),
          findsOneWidget,
        );
      }
      for (final action in [
        MessageAction.reply,
        MessageAction.copy,
        MessageAction.reportTranslation,
        MessageAction.report,
      ]) {
        expect(
          find.byKey(ValueKey('message-action-${action.name}')),
          findsNothing,
        );
      }
      await frames(tester, 2600);
      expect(find.byKey(const Key('demo2-translate-tap')), findsOneWidget);
      await frames(tester, 3000);
      expect(find.byType(MessageActionRow), findsNothing);
      expect(find.text(demo2English), findsOneWidget);
      final learning = tester.widget<MessageLearningContent>(
        find.byType(MessageLearningContent),
      );
      expect(learning.expanded, isTrue);
      expect(learning.learningLanguageCode, 'de');
      expect(learning.translation!.value!.interfaceLang, 'en');
      expect(find.text('Ich freue mich darauf!'), findsOneWidget);
      expect(
        find.text('Was wir kochen kochen wir heute Abend?', findRichText: true),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'real long press and Translate work, with no Deep Dive navigation',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(app());
      await frames(tester);
      await tester.longPress(
        find.byKey(const Key('learning-incoming-message')),
      );
      await frames(tester);
      expect(find.byType(FloatingReactionRow), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('message-action-deepDive')));
      await frames(tester);
      expect(find.byType(MessageActionRow), findsNothing);
      expect(find.text('Learn words in context'), findsOneWidget);
      await tester.longPress(
        find.byKey(const Key('learning-incoming-message')),
      );
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('message-action-translate')));
      await frames(tester);
      expect(find.text(demo2English), findsOneWidget);
      expect(find.byType(MessageActionRow), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'all normal and large states fit; actual menu/reactions remain visible; bubbles hug both lanes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [360.0, 390.0, 430.0]) {
        for (final scale in [1.0, 2.0]) {
          for (final ms in [1000, 3200, 5000, 7500, 11000]) {
            tester.view.physicalSize = Size(width, 844);
            await tester.pumpWidget(app(scale: scale));
            await frames(tester, ms);
            await frames(tester, 250);
            if (ms == 5000 || ms == 7500) {
              final row = visualRect(tester, find.byType(FloatingReactionRow));
              expect(
                row.width,
                closeTo(kFloatingReactionRowWidth * demo2PanelScale, 0.01),
              );
              expect(row.height, closeTo(44 * demo2PanelScale, 0.01));
              final selected = visualRect(
                tester,
                find.byKey(const Key('learning-incoming-message')),
              );
              final card = visualRect(tester, find.byType(MessageActionRow));
              expect(row.overlaps(selected), isFalse);
              expect(card.overlaps(selected), isFalse);
              expect(selected.top - row.bottom, greaterThanOrEqualTo(7.9));
              expect(card.top - selected.bottom, greaterThanOrEqualTo(7.9));
              expect(
                find.byKey(const ValueKey('message-action-listen')),
                findsOneWidget,
              );
              expect(
                find.byKey(const ValueKey('message-action-deepDive')),
                findsOneWidget,
              );
              expect(
                selected.top,
                greaterThanOrEqualTo(68),
                reason: '$width/$scale/$ms selected $selected',
              );
              expect(
                selected.bottom,
                lessThan(780),
                reason:
                    '$width/$scale/$ms selected $selected row $row card $card',
              );

              expect(
                find
                    .byKey(const ValueKey('message-action-translate'))
                    .hitTestable(),
                findsOneWidget,
              );
            }
            if (ms == 1000 || ms == 11000) {
              final a = visualRect(
                    tester,
                    find.byKey(const Key('learning-outgoing-message')),
                  ),
                  b = visualRect(
                    tester,
                    find.byKey(const Key('learning-incoming-message')),
                  ),
                  c = visualRect(
                    tester,
                    find.byKey(const Key('demo1-sent-translation')),
                  );
              expect(b.top - a.bottom, closeTo(16, 0.01));
              expect(c.top - b.bottom, closeTo(16, 0.01));
              expect(b.width, lessThanOrEqualTo(244.1));
              final rich = find.descendant(
                of: find.byKey(const Key('learning-incoming-message')),
                matching: find.byType(RichText),
              );
              double longest = 0;
              double paragraphHeight = 0;
              for (final f in rich.evaluate()) {
                final paragraph = f.renderObject! as RenderParagraph;
                var nested = false;
                f.visitAncestorElements((ancestor) {
                  if (ancestor.widget.key ==
                      const Key('learning-incoming-message')) {
                    return false;
                  }
                  if (ancestor.widget is RichText) {
                    nested = true;
                    return false;
                  }
                  return true;
                });
                if (!nested) {
                  paragraphHeight += paragraph.size.height;
                }
                final boxes = paragraph.getBoxesForSelection(
                  TextSelection(
                    baseOffset: 0,
                    extentOffset: paragraph.text.toPlainText().length,
                  ),
                );
                final lines = <int, List<double>>{};
                for (final box in boxes) {
                  final line = lines.putIfAbsent(
                    box.top.round(),
                    () => [box.left, box.right],
                  );
                  line[0] = math.min(line[0], box.left);
                  line[1] = math.max(line[1], box.right);
                }
                for (final line in lines.values) {
                  longest = math.max(longest, line[1] - line[0]);
                }
              }
              expect(
                b.height,
                closeTo(paragraphHeight + (ms == 11000 ? 17 : 0) + 22, 0.1),
              );
              expect(
                b.width - 26 - longest,
                lessThan(1.5),
                reason: 'Hug full longest rendered primary/secondary lane',
              );
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    },
  );
  testWidgets(
    'two complete loops show exact production Hide notice, visible tap then collapsed/no Show',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [360.0, 390.0, 430.0]) {
        for (final scale in [1.0, 2.0]) {
          tester.view.physicalSize = Size(width, 844);
          await tester.pumpWidget(app(scale: scale));
          await frames(tester, 0);
          for (var loop = 0; loop < 2; loop++) {
            var cursor = 0;
            for (final ms in [
              1000,
              5000,
              7500,
              11000,
              12500,
              12700,
              13750,
              14500,
              14900,
            ]) {
              await frames(tester, ms - cursor);
              cursor = ms;
              expect(find.text('Show translation'), findsNothing);
              if (ms == 11000 || ms == 12500 || ms == 12700) {
                final f = find.byKey(const Key('demo2-hide-translation'));
                expect(f, findsOneWidget);
                final notice = tester.widget<MessageStatusNotice>(f);
                expect(notice.text, 'Hide translation');
                expect(notice.alignRight, isFalse);
                expect(notice.color, BlabColors.warmInk);
                expect(notice.onTap, isNotNull);
                final text = tester.widget<Text>(find.text('Hide translation'));
                expect(text.style!.fontSize, 14);
                expect(text.style!.height, 1.25);
                expect(text.style!.fontWeight, FontWeight.w500);
                expect(find.text(demo2English), findsOneWidget);
              }
              if (ms == 12500 || ms == 12700) {
                expect(find.byKey(const Key('demo2-hide-tap')), findsOneWidget);
              }
              if (ms >= 13750) {
                expect(find.text(demo2English), findsNothing);
                expect(find.text('Hide translation'), findsNothing);
                expect(find.byKey(const Key('demo2-hide-tap')), findsNothing);
              }
              expect(tester.takeException(), isNull);
            }
            await frames(tester, 100);
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    },
  );
  testWidgets(
    'every expansion frame reserves full painted message and Hide notice space',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final w in [360.0, 390.0, 430.0]) {
        for (final scale in [1.0, 2.0]) {
          tester.view.physicalSize = Size(w, 844);
          await tester.pumpWidget(app(scale: scale));
          await frames(tester, 7900);
          for (var i = 0; i < 28; i++) {
            await frames(tester, 16);
            final incoming = find.byKey(const Key('learning-incoming-message'));
            final group = visualRect(tester, incoming);
            final bubble = visualRect(
              tester,
              find.descendant(
                of: incoming,
                matching: find.byType(MessageBubbleSurface),
              ),
            );
            expect(bubble.bottom, lessThanOrEqualTo(group.bottom + .01));
            final hide = find.byKey(const Key('demo2-hide-translation'));
            if (hide.evaluate().isNotEmpty) {
              expect(
                visualRect(tester, hide).bottom,
                lessThanOrEqualTo(group.bottom + .01),
              );
            }
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    },
  );
  testWidgets(
    'plain blue dot stays through holds/taps with NO ring or loading indicator',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app());
      var cursor = 0;
      for (final ms in [
        1000,
        2750,
        3250,
        3750,
        5000,
        7250,
        7750,
        11000,
        12500,
        12700,
        14000,
        14900,
      ]) {
        await frames(tester, ms - cursor);
        cursor = ms;
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        if ((ms >= 2750 && ms <= 3250) ||
            (ms >= 7250 && ms <= 7750) ||
            (ms >= 12500 && ms <= 12700)) {
          final f = find.byKey(const Key('demo2-orange-touch-dot'));
          expect(f, findsOneWidget);
          final box = tester.widget<Container>(f).decoration! as BoxDecoration;
          expect(box.color, const Color(0xFFA0C1FE));
          expect(box.shape, BoxShape.circle);
          expect(box.border, isNull);
          expect(box.boxShadow, isNull);
          expect(box.gradient, isNull);
          expect(visualRect(tester, f).size, const Size(26, 26));
        } else {
          expect(find.byKey(const Key('demo2-orange-touch-dot')), findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('real Hide tap collapses with no Show control', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app());
    await frames(tester, 11000);
    await frames(tester, 250);
    final before = visualRect(
      tester,
      find.byKey(const Key('learning-incoming-message')),
    );
    await tester.tap(find.text('Hide translation'));
    await frames(tester, 250);
    await frames(tester, 250);
    expect(find.text(demo2English), findsNothing);
    expect(find.text('Hide translation'), findsNothing);
    expect(find.text('Show translation'), findsNothing);
    expect(
      visualRect(
        tester,
        find.byKey(const Key('learning-incoming-message')),
      ).height,
      lessThan(before.height),
    );
  });
  testWidgets(
    'reduced motion static translation and accessible long-press; controls never wait',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var back = 0, next = 0, skip = 0;
      await tester.pumpWidget(
        app(
          reduced: true,
          back: () => back++,
          next: () => next++,
          skip: () => skip++,
        ),
      );
      await frames(tester);
      expect(find.text(demo2English), findsOneWidget);
      expect(find.byType(FloatingReactionRow), findsNothing);
      await tester.tap(find.text('Skip'));
      await tester.tap(find.text('Continue'));
      await tester.tap(find.byTooltip('Back'));
      expect([back, next, skip], [1, 1, 1]);
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(find.bySemanticsLabel('Demo 2 of 3'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Bestie message. Long press to translate.'),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );
}
