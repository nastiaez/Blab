import 'dart:ui' as ui;
import 'dart:io';

import 'package:blab/features/onboarding/widgets/blab_wordmark_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/deployed_wordmark.dart';

void main() {
  testWidgets('all approved letter frames match the deployed SVG renderer', (
    tester,
  ) async {
    const reference = Key('reference-frame');
    const candidate = Key('candidate-frame');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  key: reference,
                  child: DeployedWordmarkAnimation(),
                ),
                RepaintBoundary(key: candidate, child: BlabWordmarkAnimation()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // Only the frozen reference needs asynchronous SVG decoding. Do not move
    // the animation clock while loading its artwork for visual comparison.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    var previous = 0;
    for (final ms in [0, 76, 170, 220, 350, 490, 600, 720, 790]) {
      await tester.pump(Duration(milliseconds: ms - previous));
      previous = ms;
      final pixels = (await tester.runAsync(() async {
        final images = <ui.Image>[];
        for (final key in [reference, candidate]) {
          images.add(
            await tester
                .renderObject<RenderRepaintBoundary>(find.byKey(key))
                .toImage(),
          );
        }
        final before = (await images[0].toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final after = (await images[1].toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        if ([350, 600, 790].contains(ms)) {
          final output = Directory('docs/qa/2026-10-21-early-opening/parity')
            ..createSync(recursive: true);
          for (var i = 0; i < images.length; i++) {
            final png = (await images[i].toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            File(
              '${output.path}/frame$ms-$i.png',
            ).writeAsBytesSync(png.buffer.asUint8List());
          }
        }
        for (final image in images) {
          image.dispose();
        }
        return (before, after);
      }))!;
      final (before, after) = pixels;
      expect(after.lengthInBytes, before.lengthInBytes);
      var different = 0;
      var totalError = 0;
      for (var i = 0; i < before.lengthInBytes; i++) {
        final delta = (before.getUint8(i) - after.getUint8(i)).abs();
        totalError += delta;
        if (delta > 2) different++;
      }
      expect(
        different,
        lessThan(before.lengthInBytes * 0.01),
        reason: 'approved frame at ${ms}ms (subpixel edge antialiasing only)',
      );
      expect(totalError / before.lengthInBytes, lessThan(0.25));
      // ignore: avoid_print
      print(
        'PARITY ${ms}ms edgeBytes=$different meanError=${totalError / before.lengthInBytes}',
      );
    }
    await tester.pumpAndSettle();
  });
}
