import 'package:blab/features/chat/reaction_row_positioning.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rowHeight = 44.0;
  const minTop = 60.0;
  const maxBottom = 700.0;

  test('short bubble prefers the available space above by default', () {
    final bubbleRect = const Rect.fromLTWH(20, 300, 200, 50);
    final top = computeReactionRowTop(
      bubbleRect: bubbleRect,
      pressPosition: bubbleRect.center,
      rowHeight: rowHeight,
      minTop: minTop,
      maxBottom: maxBottom,
    );
    expect(top, bubbleRect.top - rowHeight - 8);
  });

  test('short bubble can use the space below when requested', () {
    final bubbleRect = const Rect.fromLTWH(20, 300, 200, 50);
    final top = computeReactionRowTop(
      bubbleRect: bubbleRect,
      pressPosition: bubbleRect.center,
      rowHeight: rowHeight,
      minTop: minTop,
      maxBottom: maxBottom,
      preferAbove: false,
    );
    expect(top, bubbleRect.bottom + 8);
  });

  test('bubble near the bottom moves the row above it', () {
    final bubbleRect = const Rect.fromLTWH(20, 640, 200, 50);
    final top = computeReactionRowTop(
      bubbleRect: bubbleRect,
      pressPosition: bubbleRect.center,
      rowHeight: rowHeight,
      minTop: minTop,
      maxBottom: maxBottom,
    );
    expect(top, bubbleRect.top - rowHeight - 8);
  });

  test('viewport-filling bubble overlaps near the press point', () {
    final bubbleRect = const Rect.fromLTWH(20, 40, 200, 700);
    final pressPosition = const Offset(120, 250);
    final top = computeReactionRowTop(
      bubbleRect: bubbleRect,
      pressPosition: pressPosition,
      rowHeight: rowHeight,
      minTop: minTop,
      maxBottom: maxBottom,
    );
    expect(top, pressPosition.dy - rowHeight - 8);
    expect(top, greaterThan(bubbleRect.top));
    expect(top + rowHeight, lessThanOrEqualTo(maxBottom));
  });

  test('overlap position stays inside both viewport bounds', () {
    final bubbleRect = const Rect.fromLTWH(20, 40, 200, 700);
    final pressPosition = const Offset(120, 50);
    final top = computeReactionRowTop(
      bubbleRect: bubbleRect,
      pressPosition: pressPosition,
      rowHeight: rowHeight,
      minTop: minTop,
      maxBottom: maxBottom,
    );
    expect(top, minTop);
  });
}
