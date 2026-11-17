import 'dart:ui' as ui;
import 'package:blab/features/chat/deep_dive_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'round dots have explicit geometry, separated gaps and no layout cost',
    (tester) async {
      final key = GlobalKey();
      const childKey = ValueKey('word');
      Future<void> mount(bool enabled) => tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: Colors.white,
                child: SizedBox(
                  width: 60,
                  height: 40,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: DeepDiveWordDots(
                      enabled: enabled,
                      child: const SizedBox(
                        key: childKey,
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await mount(false);
      final before = tester.getRect(find.byKey(childKey));
      await mount(true);
      expect(tester.getRect(find.byKey(childKey)), before);
      expect(DeepDiveWordDots.diameter, 1.3);
      expect(DeepDiveWordDots.pitch, 4);
      expect(DeepDiveWordDots.baselineOffset, 6);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 4);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        List<int> rgb(int x, int y) => List.generate(
          3,
          (c) => bytes.getUint8((y * image.width + x) * 4 + c),
        );
        expect(rgb(3, 104), [157, 148, 138]); // round dot centre
        expect(rgb(19, 104), [157, 148, 138]); // next centre, pitch4pt
        expect(rgb(10, 104), [255, 255, 255]); // visible gap, not a solid line
        expect(rgb(3, 98), [255, 255, 255]); // no thick rectangle above dot
        expect(rgb(86, 104), [255, 255, 255]); // no dots beyond this word
        image.dispose();
      });
    },
  );
}
