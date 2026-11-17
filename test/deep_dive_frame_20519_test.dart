import 'package:blab/shared/services/deep_dive_service.dart';
import 'package:blab/features/chat/deep_dive_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'deep_dive_screen_test.dart' as fixture;

void main() {
  test('Paper chrome minimum never subtracts native safe area', () {
    expect(deepDiveTopChromeGap(47), 15);
    expect(deepDiveTopChromeGap(62), 0);
    expect(deepDiveTopChromeGap(90), 0);
    expect(deepDiveTopChromeGap(24), 38);
  });
  testWidgets(
    '390 frame toolbar follows Paper minimum and respects larger inset',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      for (final top in [47.0, 62.0, 90.0]) {
        tester.view.padding = FakeViewPadding(top: top);
        tester.view.viewPadding = FakeViewPadding(top: top);
        await tester.pumpWidget(
          fixture.harness(
            service: DeepDiveService(
              viewerId: () => 'fixture',
              invoke: (_) async => {'meaning': 'fixture'},
            ),
            speech: fixture.FakeSpeech(),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getCenter(find.text('Deep Dive')).dy,
          (top < 62 ? 62 : top) + 28,
        );
      }
    },
  );
  testWidgets(
    'translation uses explicit Paper typography not Material inheritance',
    (tester) async {
      await tester.pumpWidget(
        fixture.harness(
          service: DeepDiveService(
            viewerId: () => 'fixture',
            invoke: (_) async => {'meaning': 'fixture'},
          ),
          speech: fixture.FakeSpeech(),
        ),
      );
      await tester.tap(find.byTooltip('Translate'));
      await tester.pump();
      final t = tester.widget<Text>(
        find.byKey(const ValueKey('deep-dive-translation')),
      );
      expect(t.style!.fontSize, 16);
      expect(t.style!.height, 1.5);
      expect(t.style!.letterSpacing, 0);
      expect(t.style!.fontWeight, FontWeight.w400);
      expect(t.style!.color, const Color(0xFF5F6770));
    },
  );
}
