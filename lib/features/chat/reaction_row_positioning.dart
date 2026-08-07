import 'package:flutter/material.dart';

/// Computes the top Y coordinate (in the same coordinate space as
/// [bubbleRect] and [pressPosition]) for the floating reaction row.
///
/// Default: the row sits flush against the top of the bubble (no gap).
/// When the bubble is short and there's room above it, that's exactly what
/// happens. When the bubble is tall (more than [tallBubbleThreshold]
/// logical pixels — roughly 3 lines of text or a photo) or there simply
/// isn't room above it, the row instead anchors near where the user
/// actually pressed rather than the bubble's true (possibly off-screen)
/// top, staying visually attached to the touch point. [minTop] is a hard
/// floor — the row's top never goes above it (e.g. above the status bar),
/// though it's allowed to overlap page content like the chat header.
double computeReactionRowTop({
  required Rect bubbleRect,
  required Offset pressPosition,
  required double rowHeight,
  required double minTop,
  double tallBubbleThreshold = 120,
  double pressGap = 8,
}) {
  final isTall = bubbleRect.height > tallBubbleThreshold;
  final flushTop = bubbleRect.top - rowHeight;
  if (!isTall && flushTop >= minTop) {
    return flushTop;
  }
  final pressAnchoredTop = pressPosition.dy - rowHeight - pressGap;
  return pressAnchoredTop < minTop ? minTop : pressAnchoredTop;
}
