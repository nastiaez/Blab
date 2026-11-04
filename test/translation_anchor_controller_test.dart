import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blab/features/chat/translation_anchor_controller.dart';

void main() {
  for (final count in [3, 12]) {
    for (final expansion in [80.0, 700.0]) {
      testWidgets('row anchor: $count rows, $expansion extra height', (
        t,
      ) async {
        final controller = TranslationAnchorController();
        final keys = List.generate(count, (_) => GlobalKey());
        final target = count - 2;
        var expanded = false;
        var leading = 0.0;
        late StateSetter rebuild;
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return ListView(
                    reverse: true,
                    scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
                    controller: controller,
                    padding: EdgeInsets.only(top: leading),
                    children: List.generate(
                      count,
                      (i) => TranslationAnchor(
                        key: keys[i],
                        anchorKey: keys[i],
                        controller: controller,
                        child: SizedBox(
                          height:
                              80 + (i == target && expanded ? expansion : 0),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text('row $i'),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        controller.jumpTo(controller.position.maxScrollExtent);
        await t.pumpAndSettle();
        final original = t.getTopLeft(find.text('row $target'));
        final above = t.getTopLeft(find.text('row ${target + 1}'));
        final below = t.getTopLeft(
          find.text('row ${target - 1}', skipOffstage: false),
        );
        leading += controller.leadingWhitespace(keys[target]);
        controller.preserve(keys[target]);
        rebuild(() => expanded = true);
        await t.pumpAndSettle();
        expect(t.getTopLeft(find.text('row $target')), original);
        expect(t.getTopLeft(find.text('row ${target + 1}')), above);
        expect(
          t.getTopLeft(find.text('row ${target - 1}', skipOffstage: false)).dy,
          closeTo(below.dy + expansion, .1),
        );
        controller.preserve(keys[target]);
        rebuild(() => expanded = false);
        await t.pumpAndSettle();
        expect(t.getTopLeft(find.text('row $target')), original);
        expect(t.getTopLeft(find.text('row ${target + 1}')), above);
        expect(
          t.getTopLeft(find.text('row ${target - 1}', skipOffstage: false)),
          below,
        );
        await t.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      });
    }
  }
}
