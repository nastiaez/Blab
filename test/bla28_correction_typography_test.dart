import 'package:blab/features/chat/widgets/inline_correction_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final width in [180.0, 360.0]) {
      for (final lookup in [false, true]) {
        testWidgets(
          'provenance gap and uniform size width$width scale$scale lookup$lookup',
          (tester) async {
            const source = 'Ich ist tired.';
            final segments = authoredCorrectionSegments(source, {
              'version': 'a-v1',
              'source': source,
              'correctionText': 'Ich bin tired.',
              'corrections': [
                {'start': 4, 'end': 7, 'original': 'ist', 'replacement': 'bin'},
              ],
            });
            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  home: Scaffold(
                    body: MediaQuery(
                      data: MediaQueryData(
                        textScaler: TextScaler.linear(scale),
                      ),
                      child: DefaultTextStyle(
                        style: const TextStyle(fontSize: 27),
                        child: SizedBox(
                          width: width,
                          child: InlineCorrectionText(
                            originalText: source,
                            correctedText: 'Ich bin tired.',
                            segments: segments,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: Colors.black,
                            ),
                            learningLanguageCode: 'de',
                            popupTopInset: 0,
                            enableWordLookup: lookup,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            final text = tester.widget<Text>(
              find.byKey(const ValueKey('inline-correction')),
            );
            final spans = (text.textSpan! as TextSpan).children!;
            final struckIndex = spans.indexWhere(
              (s) =>
                  s is WidgetSpan &&
                  (s.child as Padding).child is Text &&
                  ((s.child as Padding).child as Text).data == 'ist',
            );
            expect(struckIndex, greaterThanOrEqualTo(0));
            expect((spans[struckIndex + 1] as TextSpan).text, ' ');
            expect(
              (spans[struckIndex + 1] as TextSpan).style?.decoration,
              isNot(TextDecoration.lineThrough),
            );
            final wordParagraphs = tester
                .renderObjectList<RenderParagraph>(
                  find.descendant(
                    of: find.byType(InlineCorrectionText),
                    matching: find.byType(RichText),
                  ),
                )
                .where(
                  (p) => [
                    'Ich',
                    'ist',
                    'bin',
                    'tired',
                  ].contains(p.text.toPlainText()),
                )
                .toList();
            expect(wordParagraphs.length, 4);
            for (final paragraph in wordParagraphs) {
              final root = paragraph.text as TextSpan;
              final style = root.children?.first.style ?? root.style;
              expect(style?.fontSize, 16);
              expect(paragraph.textScaler.scale(16), 16 * scale);
            }
            final corrected = wordParagraphs.singleWhere(
              (p) => p.text.toPlainText() == 'bin',
            );
            final correctedRoot = corrected.text as TextSpan;
            expect(
              (correctedRoot.children?.first.style ?? correctedRoot.style)
                  ?.fontWeight,
              FontWeight.w600,
            );
            expect(tester.takeException(), isNull);
            // Source/provenance remain byte-exact; the new gap is visual only.
            expect(
              segments.where((s) => !s.struck).map((s) => s.text).join(),
              'Ich bin tired.',
            );
          },
        );
      }
    }
  }
}
