import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'learn_in_context_screen_test.dart' as fixture;

void checkHug(WidgetTester tester, String key, {bool incoming = false}) {
  final f = find.byKey(Key(key));
  final rect = tester.getRect(f);
  final rich = find.descendant(of: f, matching: find.byType(RichText));
  expect(rich, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(rich);
  final text = paragraph.text.toPlainText();
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  // Selection boxes split at bold spans; union each actual rendered line.
  final lines = <int, List<double>>{};
  for (final box in boxes) {
    final key = box.top.round();
    final range = lines.putIfAbsent(key, () => [box.left, box.right]);
    range[0] = math.min(range[0], box.left);
    range[1] = math.max(range[1], box.right);
  }
  final longest = lines.values.fold<double>(
    0,
    (width, range) => math.max(width, range[1] - range[0]),
  );
  expect(
    paragraph.size.width - longest,
    lessThanOrEqualTo(1.5),
    reason: 'No fixed-width blank space after actual rendered line',
  );
  expect(
    rect.width,
    closeTo(paragraph.size.width + (incoming ? 26 : 24), 0.01),
  );
  expect(
    rect.height,
    closeTo(paragraph.size.height + (incoming ? 22 : 20), 0.01),
  );
  expect(rect.width, lessThanOrEqualTo(incoming ? 244 : 250));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/deep_dive/Roboto-Variable.ttf'));
    await loader.load();
  });
  testWidgets(
    'exact German word-order correction and English to German composer sequence',
    (tester) async {
      await tester.pumpWidget(fixture.app());
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Was wir kochen heute Abend?'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 4000));
      expect(
        find.text('Was wir kochen kochen wir heute Abend?', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Was wir kochen heute Abend?'), findsNothing);
      await tester.pump(const Duration(milliseconds: 5000));
      expect(
        find.text('Ich kann ein vorzügliches Pilzrisotto machen.'),
        findsOneWidget,
      );
      expect(find.text('I’m looking forward to it!'), findsOneWidget);
      expect(find.byKey(const Key('demo1-sent-translation')), findsNothing);
      await tester.pump(const Duration(milliseconds: 2000));
      expect(find.text('Ich freue mich darauf!'), findsOneWidget);
      expect(find.text('I’m looking forward to it!'), findsNothing);
      expect(find.text('Build natural sentences'), findsOneWidget);
    },
  );
  testWidgets(
    'all bubble containers hug rendered content before and after correction and translation',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [360.0, 390.0, 430.0]) {
        for (final scale in [1.0, 2.0]) {
          for (final time in [1000, 5000, 10000, 12000]) {
            tester.view.physicalSize = Size(width, 844);
            await tester.pumpWidget(fixture.app(scale: scale));
            await tester.pump(Duration(milliseconds: time));
            await tester.pump(const Duration(milliseconds: 200));
            checkHug(tester, 'learning-outgoing-message');
            if (time >= 10000) {
              checkHug(tester, 'learning-incoming-message', incoming: true);
              final a = tester.getRect(
                    find.byKey(const Key('learning-outgoing-message')),
                  ),
                  b = tester.getRect(
                    find.byKey(const Key('learning-incoming-message')),
                  );
              expect(b.top - a.bottom, closeTo(16, 0.01));
              if (time >= 12000) {
                checkHug(tester, 'demo1-sent-translation');
                final c = tester.getRect(
                  find.byKey(const Key('demo1-sent-translation')),
                );
                expect(c.top - b.bottom, closeTo(16, 0.01));
              }
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    },
  );
}
