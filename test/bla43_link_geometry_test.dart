import 'package:blab/features/chat/widgets/anchored_message_panels.dart';
import 'package:blab/features/chat/widgets/message_interaction_target.dart';
import 'package:blab/features/chat/widgets/message_link_anchor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'message_link_text_test.dart' as fixture;

void main() {
  for (final outgoing in [false, true]) {
    for (final body in [
      'Message https://example.com/Berlin',
      'Message on several lines before the URL https://example.com/Berlin',
      'Message https://example.com/${List.filled(60, 'long-route/').join()}',
    ]) {
      for (final edge in ['top', 'middle', 'bottom']) {
        for (final keyboard in [false, true]) {
          testWidgets(
            'BLA43 geometry $outgoing ${body.length} $edge keyboard=$keyboard',
            (tester) async {
              tester.view.physicalSize = const Size(400, 800);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              final viewport = Rect.fromLTRB(16, 88, 384, keyboard ? 440 : 720);
              final bubbleKey = GlobalKey();
              await tester.pumpWidget(
                MaterialApp(
                  home: Scaffold(
                    body: MessageLinkAnchor(
                      viewport: () => viewport,
                      child: Stack(
                        children: [
                          Positioned(
                            left: outgoing ? null : 12,
                            right: outgoing ? 12 : null,
                            top: edge == 'top'
                                ? 92
                                : edge == 'middle'
                                ? 240
                                : null,
                            bottom: edge == 'bottom'
                                ? 800 - viewport.bottom + 12
                                : null,
                            width: body.length > 60 ? 280 : 300,
                            child: MessageInteractionTarget(
                              key: bubbleKey,
                              isFailed: false,
                              onLongPress: (_, _) {},
                              onFailedTap: () {},
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: fixture.links(body, outgoing: outgoing),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              await fixture.holdLink(tester);
              final bubble = tester.getRect(find.byKey(bubbleKey));
              final menu = tester.getRect(
                find.byKey(const ValueKey('link-actions-container')),
              );
              final expected = placeMessagePanels(
                viewport: viewport,
                bubble: bubble,
                height: menu.height,
                afterVisibleLines: bubble.top + 84,
              );

              if (expected != null) {
                expect(menu.top, closeTo(expected.top, .01));
              } else {
                expect(
                  menu.top,
                  closeTo(
                    (bubble.top + 84).clamp(
                      viewport.top,
                      viewport.bottom - menu.height,
                    ),
                    .01,
                  ),
                );
              }
              expect(
                menu.left,
                closeTo(
                  (bubble.center.dx - menu.width / 2).clamp(
                    viewport.left,
                    viewport.right - menu.width,
                  ),
                  .01,
                ),
              );
              expect(menu.top, greaterThanOrEqualTo(viewport.top));
              expect(menu.bottom, lessThanOrEqualTo(viewport.bottom));
              if (expected != null) {
                expect(
                  expected.below
                      ? menu.top - bubble.bottom
                      : bubble.top - menu.bottom,
                  closeTo(8, .01),
                );
              }
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
