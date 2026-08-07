import 'package:blab/features/chat/reaction_row_positioning.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rowHeight = 44.0;
  const minTop = 60.0;

  test('short bubble with room above sits flush against the bubble top', () {
    final bubbleRect = const Rect.fromLTWH(20, 300, 200, 50);
    final top = computeReactionRowTop(
      bubbleRect: bubbleRect,
      pressPosition: bubbleRect.center,
      rowHeight: rowHeight,
      minTop: minTop,
    );
    expect(top, bubbleRect.top - rowHeight);
  });

  test('short bubble near the top clamps to press position, not flush', () {
    final bubbleRect = const Rect.fromLTWH(20, 90, 200, 50);
    final pressPosition = const Offset(120, 130);
    final top = computeReactionRowTop(
      bubbleRect: bubbleRect,
      pressPosition: pressPosition,
      rowHeight: rowHeight,
      minTop: minTop,
    );
    // flush (90 - 44 = 46) is below minTop, so it anchors near the press
    // point instead: 130 - 44 - 8 = 78, which clears minTop on its own
    // (no further clamp needed) and sits below the bubble's true top.
    expect(top, pressPosition.dy - rowHeight - 8);
    expect(top, greaterThanOrEqualTo(minTop));
    expect(top, lessThan(bubbleRect.top));
  });

  test('tall bubble anchors near the press point, not the true bubble top', () {
    final bubbleRect = const Rect.fromLTWH(20, -300, 200, 500);
    final pressPosition = const Offset(120, 250);
    final top = computeReactionRowTop(
      bubbleRect: bubbleRect,
      pressPosition: pressPosition,
      rowHeight: rowHeight,
      minTop: minTop,
    );
    expect(top, pressPosition.dy - rowHeight - 8);
    expect(top, greaterThan(bubbleRect.top));
  });

  test('tall bubble still respects the minimum top clamp', () {
    final bubbleRect = const Rect.fromLTWH(20, -300, 200, 500);
    final pressPosition = const Offset(120, 50);
    final top = computeReactionRowTop(
      bubbleRect: bubbleRect,
      pressPosition: pressPosition,
      rowHeight: rowHeight,
      minTop: minTop,
    );
    expect(top, minTop);
  });
}
