import 'dart:ui' as ui;
import 'package:blab/app/design_tokens.dart';
import 'package:blab/features/chat/deep_dive_typography.dart';
import 'package:blab/shared/services/deep_dive_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'deep_dive_screen_test.dart' as fixture;

void main() {
  testWidgets(
    'Paper 3px selection paints all four rounded corners with unchanged layout',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(64, 64);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final key = GlobalKey();
      Widget tree(bool selected) => RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: BlabColors.chatSurface,
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: DeepDiveSelectedWordBackground(
                selected: selected,
                child: const SizedBox(width: 40, height: 23),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(tree(false));
      final before = tester.getSize(
        find.byType(DeepDiveSelectedWordBackground),
      );
      await tester.pumpWidget(tree(true));
      expect(
        tester.getSize(find.byType(DeepDiveSelectedWordBackground)),
        before,
      );
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1);
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        Color pixel(int x, int y) {
          final i = (y * image.width + x) * 4;
          return Color.fromARGB(
            data.getUint8(i + 3),
            data.getUint8(i),
            data.getUint8(i + 1),
            data.getUint8(i + 2),
          );
        }

        expect(DeepDiveSelectedWordBackground.radius, 3);
        expect(DeepDiveSelectedWordBackground.bottomExtent, 4);
        for (final p in [
          const Offset(10, 10),
          const Offset(49, 10),
          const Offset(10, 36),
          const Offset(49, 36),
        ]) {
          expect(pixel(p.dx.toInt(), p.dy.toInt()), isNot(BlabColors.warmInk));
        }
        expect(pixel(30, 12), BlabColors.warmInk);
        expect(pixel(30, 35), BlabColors.warmInk);
        image.dispose();
      });
    },
  );
  testWidgets(
    'Translate pink follows exclusive translation slot and native selected semantics',
    (tester) async {
      await tester.pumpWidget(
        fixture.harness(
          service: DeepDiveService(
            viewerId: () => 'ui-state-only',
            invoke: (_) async => {
              'meaning': 'UI state fixture',
              'explanation': 'UI state fixture',
            },
          ),
          speech: fixture.FakeSpeech(),
        ),
      );
      IconButton button() => tester.widget<IconButton>(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Translate',
        ),
      );
      Color? fill() => button().style!.backgroundColor!.resolve({
        if (button().isSelected!) WidgetState.selected,
      });
      expect(button().isSelected, false);
      expect(fill(), Colors.transparent);
      await tester.tap(find.byTooltip('Translate'));
      await tester.pump();
      expect(button().isSelected, true);
      expect(fill(), BlabColors.selectedTint);
      expect(button().style!.fixedSize!.resolve({}), const Size(48, 48));
      expect(button().style!.shape!.resolve({}), isA<CircleBorder>());
      await tester.tap(find.byTooltip('Translate'));
      await tester.pump();
      expect(button().isSelected, false);
      expect(fill(), Colors.transparent);
      await tester.tap(find.byTooltip('Translate'));
      await tester.pump();
      await tester.tap(find.text('bing').first);
      await tester.pump();
      expect(button().isSelected, false);
      expect(fill(), Colors.transparent);
      expect(find.text('Translation'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
