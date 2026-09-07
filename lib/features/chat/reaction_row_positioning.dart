import 'package:flutter/material.dart';

/// Computes the top Y coordinate (in the same coordinate space as
/// [bubbleRect] and [pressPosition]) for the floating reaction row.
///
/// The row prefers the space above the selected bubble. If that space is
/// unavailable, it moves below it. Only when the selected message leaves no
/// full row-sized space on either side does the row overlap that message near
/// the long-press position. This intentionally lets the row float over other
/// message bubbles; [minTop] and [maxBottom] keep it clear of the
/// system/header edge and the message-action row.
double computeReactionRowTop({
  required Rect bubbleRect,
  required Offset pressPosition,
  required double rowHeight,
  required double minTop,
  required double maxBottom,
  double gap = 8,
  bool preferAbove = true,
}) {
  final aboveTop = bubbleRect.top - rowHeight - gap;
  final belowTop = bubbleRect.bottom + gap;
  final aboveFits = aboveTop >= minTop;
  final belowFits = belowTop + rowHeight <= maxBottom;

  if (preferAbove && aboveFits) {
    return aboveTop;
  }
  if (!preferAbove && belowFits) {
    return belowTop;
  }
  if (belowFits) return belowTop;
  if (aboveFits) return aboveTop;

  final maxTop = maxBottom - rowHeight;
  if (maxTop <= minTop) return minTop;
  return (pressPosition.dy - rowHeight - gap).clamp(minTop, maxTop).toDouble();
}
