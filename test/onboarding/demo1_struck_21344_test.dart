import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'learn_in_context_screen_test.dart' as fixture;

void main() {
  testWidgets(
    'normal original has no diff; removed phrase stays struck in corrected holds and final',
    (tester) async {
      await tester.pumpWidget(fixture.app());
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Was wir kochen heute Abend?'), findsOneWidget);
      for (final step in [4000, 3500, 3500]) {
        await tester.pump(Duration(milliseconds: step));
        await tester.pump(const Duration(milliseconds: 160));
        final f = find.descendant(
          of: find.byKey(const Key('learning-outgoing-message')),
          matching: find.byType(Text),
        );
        final text = tester.widget<Text>(f);
        final root = text.textSpan! as TextSpan;
        final spans = root.children!.cast<TextSpan>();
        final removed = spans.singleWhere((s) => s.text == 'wir kochen');
        expect(removed.style!.decoration, TextDecoration.lineThrough);
        expect(removed.style!.decorationThickness, 2);
        expect(removed.style!.color, const Color(0xAD231208));
        expect(
          spans.singleWhere((s) => s.text == 'kochen wir').style!.fontWeight,
          FontWeight.w700,
        );
        expect(
          spans
              .where((s) => s.style?.decoration != TextDecoration.lineThrough)
              .map((s) => s.text)
              .join(),
          'Was  kochen wir heute Abend?',
        );
        expect(text.semanticsLabel, 'Was kochen wir heute Abend?');
        expect(root.toPlainText(), 'Was wir kochen kochen wir heute Abend?');
        final removedBox = find.descendant(
          of: find.byKey(const Key('learning-outgoing-message')),
          matching: find.byType(Opacity),
        );
        for (final opacity in tester.widgetList<Opacity>(removedBox)) {
          expect(opacity.opacity, greaterThan(0));
        }
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Ich freue mich darauf!'), findsOneWidget);
    },
  );
  testWidgets(
    'reduced-motion final also retains full visible struck replacement',
    (tester) async {
      await tester.pumpWidget(fixture.app(reduced: true));
      await tester.pump();
      expect(
        find.text('Was wir kochen kochen wir heute Abend?', findRichText: true),
        findsOneWidget,
      );
    },
  );
}
