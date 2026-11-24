import 'package:blab/app/theme.dart';
import 'package:blab/features/onboarding/widgets/demo_conversation_phone.dart';
import 'package:blab/features/onboarding/widgets/demo2_phone.dart';
import 'package:blab/features/onboarding/widgets/demo3_phone.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => ProviderScope(
  child: MaterialApp(
    theme: blabTheme,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: Center(child: SizedBox(width: 306, height: 468, child: child)),
    ),
  ),
);
Future<void> show(WidgetTester t, Widget child) async {
  await t.pumpWidget(host(child));
  await t.pump();
  await t.pump();
}

void main() {
  testWidgets('Demo1 glyph baseline never travels vertically during reveal', (
    t,
  ) async {
    final baselines = <double>[];
    for (var ms = 3700; ms <= 3990; ms += 10) {
      await t.pumpWidget(
        host(
          DemoConversationPhone(milliseconds: ms, reduced: false, large: false),
        ),
      );
      await t.pump(const Duration(milliseconds: 10));
      final rich = find
          .descendant(
            of: find.byKey(const Key('learning-outgoing-message')),
            matching: find.byType(RichText),
          )
          .first;
      final paragraph = t.renderObject<RenderParagraph>(rich);
      final baseline = paragraph
          .localToGlobal(
            Offset(
              0,
              paragraph
                  .getBoxesForSelection(
                    const TextSelection(baseOffset: 0, extentOffset: 1),
                  )
                  .first
                  .top,
            ),
          )
          .dy;
      baselines.add(baseline);
    }
    debugPrint('DEMO1_GLYPH_BASELINES $baselines');
    for (final baseline in baselines) {
      expect(baseline, closeTo(baselines.last, .001));
    }
  });
  testWidgets('Demo1 correction growth stays top anchored at every frame', (
    t,
  ) async {
    final samples = <Map<String, double>>[];
    for (var ms = 3400; ms <= 4050; ms += 10) {
      await t.pumpWidget(
        host(
          DemoConversationPhone(milliseconds: ms, reduced: false, large: false),
        ),
      );
      await t.pump(const Duration(milliseconds: 10));
      final bubble = find.byKey(const Key('learning-outgoing-message'));
      final container = find
          .descendant(of: bubble, matching: find.byType(Container))
          .first;
      final header = t.getRect(find.byKey(const Key('demo1-chat-header')));
      final rect = t.getRect(container);
      samples.add({
        'ms': ms.toDouble(),
        'top': rect.top - header.bottom,
        'height': rect.height,
      });
    }
    debugPrint('DEMO1_INTERMEDIATE_GEOMETRY $samples');
    for (final sample in samples) {
      expect(
        sample['top'],
        closeTo(44, .001),
        reason: 'intermediate frame $sample',
      );
    }
    expect(samples.last['height'], greaterThan(samples.first['height']!));
  });
  testWidgets('all three first messages use the approved Demo1 header inset', (
    t,
  ) async {
    final gaps = <double>[];
    for (final child in <Widget>[
      const DemoConversationPhone(
        milliseconds: 12000,
        reduced: true,
        large: false,
      ),
      const Demo2Phone(milliseconds: 1000, reduced: false, large: false),
      const Demo3Phone(milliseconds: 1000, reduced: false, large: false),
    ]) {
      await show(t, child);
      gaps.add(
        t.getRect(find.byKey(const Key('learning-outgoing-message'))).top -
            t.getRect(find.byKey(const Key('demo1-chat-header'))).bottom,
      );
    }
    expect(gaps, equals(<double>[44, 44, 44]));
  });
  testWidgets(
    'Hide keeps preceding and German message tops fixed and moves following reply up',
    (t) async {
      await show(
        t,
        const Demo2Phone(milliseconds: 11000, reduced: false, large: false),
      );
      final first = t
          .getRect(find.byKey(const Key('learning-outgoing-message')))
          .top;
      final incoming = t
          .getRect(find.byKey(const Key('learning-incoming-message')))
          .top;
      final following = t
          .getRect(find.byKey(const Key('demo1-sent-translation')))
          .top;
      await show(
        t,
        const Demo2Phone(milliseconds: 14500, reduced: false, large: false),
      );
      expect(
        t.getRect(find.byKey(const Key('learning-outgoing-message'))).top,
        first,
      );
      expect(
        t.getRect(find.byKey(const Key('learning-incoming-message'))).top,
        incoming,
      );
      expect(
        t.getRect(find.byKey(const Key('demo1-sent-translation'))).top,
        lessThan(following),
      );
      expect(find.text('Hide translation'), findsNothing);
    },
  );
}
