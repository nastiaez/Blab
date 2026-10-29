import 'package:blab/features/chat/widgets/mention_picker_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'suggestions overlay history, remain tappable, and follow composer height',
    (tester) async {
      final visible = ValueNotifier(false);
      final tall = ValueNotifier(false);
      var selected = false;
      addTearDown(visible.dispose);
      addTearDown(tall.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: Listenable.merge([visible, tall]),
              builder: (context, _) => Column(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        key: const Key('history'),
                        height: 200,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  MentionPickerOverlay(
                    picker: visible.value
                        ? Material(
                            child: InkWell(
                              onTap: () => selected = true,
                              child: const SizedBox(
                                height: 100,
                                child: Text('Alice'),
                              ),
                            ),
                          )
                        : null,
                    child: SizedBox(
                      key: const Key('composer'),
                      height: tall.value ? 130 : 60,
                      width: double.infinity,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final history = tester.getRect(find.byKey(const Key('history')));
      final composer = tester.getRect(find.byKey(const Key('composer')));
      visible.value = true;
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(const Key('history'))), history);
      expect(tester.getRect(find.byKey(const Key('composer'))), composer);
      expect(
        tester.getBottomLeft(find.text('Alice')).dy,
        lessThan(composer.top),
      );
      await tester.tap(find.text('Alice'));
      expect(selected, isTrue);
      tall.value = true;
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(find.text('Alice')).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('composer'))).dy),
      );
      visible.value = false;
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
