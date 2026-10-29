import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blab/features/chat/widgets/anchored_message_panels.dart';

void main() {
  testWidgets('whole chat scroll has finite endpoint while panels stay fixed', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ListView(
                controller: scroll,
                children: const [
                  SizedBox(height: 883, child: Text('natural final message')),
                ],
              ),
              const Positioned.fill(
                child: AnchoredMessagePanels(
                  viewport: Rect.fromLTRB(16, 0, 784, 600),
                  bubble: Rect.fromLTRB(20, 16, 315, 899),
                  afterVisibleLines: 96,
                  translationTop: 568,
                  reactionWidth: 278,
                  actions: SizedBox(
                    width: 202,
                    height: 208,
                    child: Text('actions'),
                  ),
                  reactions: SizedBox(
                    width: 278,
                    height: 44,
                    child: Text('emojis'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.text('actions'));
    final extent = scroll.position.maxScrollExtent;
    await tester.dragFrom(const Offset(600, 450), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(scroll.offset, extent);
    expect(scroll.position.maxScrollExtent, extent);
    expect(tester.getTopLeft(find.text('actions')), before);
    expect(
      tester.getTopLeft(find.text('emojis')).dy -
          tester.getBottomLeft(find.text('actions')).dy,
      greaterThanOrEqualTo(8),
    );
  });

  const viewport = Rect.fromLTRB(0, 108, 411, 824);
  test('below is preferred before above', () {
    expect(
      placeMessagePanels(
        viewport: viewport,
        bubble: const Rect.fromLTRB(12, 400, 200, 440),
        height: 260,
        afterVisibleLines: 480,
      ),
      (top: 448.0, below: true),
    );
  });
  test('last short uses above', () {
    expect(
      placeMessagePanels(
        viewport: viewport,
        bubble: const Rect.fromLTRB(12, 744, 200, 804),
        height: 260,
        afterVisibleLines: 800,
      ),
      (top: 476.0, below: false),
    );
  });
  test('long overlap follows visible opening and clears translation', () {
    expect(
      placeMessagePanels(
        viewport: viewport,
        bubble: const Rect.fromLTRB(12, 124, 307, 1007),
        height: 260,
        afterVisibleLines: 212,
        translationTop: 676,
      ),
      (top: 212.0, below: false),
    );
    expect(
      placeMessagePanels(
        viewport: viewport,
        bubble: const Rect.fromLTRB(12, 124, 307, 1007),
        height: 260,
        afterVisibleLines: 300,
        translationTop: 483,
      ),
      (top: 215.0, below: false),
    );
  });
  test('unapproved overflow is explicit, not a top pin', () {
    expect(
      placeMessagePanels(
        viewport: viewport,
        bubble: const Rect.fromLTRB(12, 100, 307, 1007),
        height: 800,
        afterVisibleLines: 212,
      ),
      isNull,
    );
  });
}
