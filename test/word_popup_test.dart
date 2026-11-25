import 'package:blab/features/chat/widgets/word_popup.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Tts implements TtsService {
  int stops = 0;
  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  for (final anchor in [const Offset(0, 60), const Offset(370, 700)]) {
    testWidgets('shared popup clamps and dismisses at $anchor', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final tts = _Tts();
      var dismissed = 0;
      late BuildContext host;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                host = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      showLearningWordPopup(
        host,
        card: const SizedBox(
          width: 280,
          height: 130,
          child: Text('shared details'),
        ),
        wordTopLeft: anchor,
        wordSize: const Size(20, 20),
        tts: tts,
        topInset: 50,
        onDismiss: () => dismissed++,
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.text('shared details'));
      expect(rect.left, greaterThanOrEqualTo(12));
      expect(rect.right, lessThanOrEqualTo(378));
      expect(rect.top, greaterThanOrEqualTo(50));
      await tester.tapAt(const Offset(195, 820));
      await tester.pumpAndSettle();
      expect(find.text('shared details'), findsNothing);
      expect(dismissed, 1);
      expect(tts.stops, 1);
    });
  }
  testWidgets('replacement and lifecycle dismissal close only current popup', (
    tester,
  ) async {
    late BuildContext host;
    final tts = _Tts();
    var dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              host = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    void open(String text) => showLearningWordPopup(
      host,
      card: SizedBox(width: 250, height: 120, child: Text(text)),
      wordTopLeft: const Offset(100, 300),
      wordSize: const Size(30, 20),
      tts: tts,
      onDismiss: () => dismissed++,
    );
    open('first');
    await tester.pumpAndSettle();
    open('second');
    await tester.pumpAndSettle();
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
    expect(dismissed, 1);
    dismissWordPopup();
    await tester.pumpAndSettle();
    dismissWordPopup();
    expect(find.text('second'), findsNothing);
    expect(dismissed, 2);
    expect(tts.stops, 2);
  });
}
