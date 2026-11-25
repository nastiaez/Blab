/// Shared measured popup positioning and dismissal for Deep Dive.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/services/tts_service.dart';

/// Currently-visible popup entry, so we can close it before opening a new
/// one. Mutable singleton tracked at library scope — only ever one popup at
/// a time per PRD.
OverlayEntry? _currentEntry;
TtsService? _currentTts;
VoidCallback? _currentOnDismiss;

void _dismissCurrent() {
  final entry = _currentEntry;
  final tts = _currentTts;
  final onDismiss = _currentOnDismiss;
  _currentEntry = null;
  _currentTts = null;
  _currentOnDismiss = null;
  entry?.remove();
  onDismiss?.call();
  if (tts != null) unawaited(tts.stop());
}

/// Dismisses the currently-open word popup, if one is showing.
/// No-op otherwise.
///
/// Shared by Deep Dive lifecycle handlers and ModeToggle.
void dismissWordPopup() => _dismissCurrent();

/// Maximum popup card width (PRD FR-12).
const double _kMaxPopupWidth = 280;

/// Minimum gap between popup edge and screen edge.
const double _kEdgePadding = 12;

/// Tail size.
const double _kTailWidth = 16;
const double _kTailHeight = 10;
const double _kPopupStrokeWidth = 1;
const Color _kPopupStroke = BlabColors.chatDivider;

/// Reuses the existing measured/clamped popup positioning for Deep Dive.
void showLearningWordPopup(
  BuildContext context, {
  required Widget card,
  required Offset wordTopLeft,
  required Size wordSize,
  required TtsService tts,
  double topInset = 0,
  VoidCallback? onDismiss,
}) {
  _dismissCurrent();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _PositionedPopup(
      card: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.sizeOf(context).width - 24)
              .clamp(1, 280)
              .toDouble(),
          maxHeight: (MediaQuery.sizeOf(context).height - topInset - 44)
              .clamp(1, double.infinity)
              .toDouble(),
        ),
        child: SingleChildScrollView(child: card),
      ),
      compactAnchor: true,
      wordTopLeft: wordTopLeft,
      wordSize: wordSize,
      screen: MediaQuery.sizeOf(context),
      topInset: topInset,
      onTapOutside: () {
        if (_currentEntry == entry) _dismissCurrent();
      },
    ),
  );
  _currentEntry = entry;
  _currentTts = tts;
  _currentOnDismiss = onDismiss;
  Overlay.of(context, rootOverlay: true).insert(entry);
}

/// Builds the card + tail and positions it relative to the tapped word.
/// Measures itself to clamp horizontally / flip vertically.
class _PositionedPopup extends StatefulWidget {
  const _PositionedPopup({
    required this.card,
    required this.wordTopLeft,
    required this.wordSize,
    required this.screen,
    required this.topInset,
    required this.onTapOutside,
    this.compactAnchor = false,
  });

  final bool compactAnchor;

  /// Popup content. Wrapped internally in a measuring [KeyedSubtree], so the
  /// caller doesn't need to attach a key.
  final Widget card;
  final Offset wordTopLeft;
  final Size wordSize;
  final Size screen;
  final double topInset;
  final VoidCallback onTapOutside;

  @override
  State<_PositionedPopup> createState() => _PositionedPopupState();
}

class _PositionedPopupState extends State<_PositionedPopup> {
  final GlobalKey _cardKey = GlobalKey();
  Size? _cardSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant _PositionedPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final ctx = _cardKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if (_cardSize != box.size) {
      setState(() => _cardSize = box.size);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _measure();
        });
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: KeyedSubtree(key: _cardKey, child: widget.card),
      ),
    );

    // First frame: render off-screen / invisible to measure.
    final size = _cardSize;
    if (size == null) {
      return Positioned(
        left: -9999,
        top: -9999,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxPopupWidth),
          child: card,
        ),
      );
    }

    final tailHeight = widget.compactAnchor ? 8.0 : _kTailHeight;
    final wordCenterX = widget.wordTopLeft.dx + widget.wordSize.width / 2;
    final wordTopY = widget.wordTopLeft.dy;
    final wordBottomY = widget.wordTopLeft.dy + widget.wordSize.height;

    // BUG-009: clamp the popup's top edge below the chat header (or any
    // other caller-supplied top inset) so it doesn't overlap persistent
    // chrome.
    final minTop = widget.topInset + _kEdgePadding;

    // Decide flip: prefer above. If less than cardHeight + 16 above, flip.
    // The space above is measured down to [minTop], not zero — otherwise we
    // could "fit" by drawing into the header.
    final spaceAbove = wordTopY - minTop;
    final needed = size.height + tailHeight + 8;
    final flipBelow = spaceAbove < needed;

    // Horizontal: center card on word center, clamp inside screen.
    double left = wordCenterX - size.width / 2;
    final edge = widget.compactAnchor ? 16.0 : _kEdgePadding;
    final minLeft = edge;
    final maxLeft = widget.screen.width - size.width - edge;
    if (widget.compactAnchor) {
      left = wordCenterX >= widget.screen.width / 2 ? maxLeft : minLeft;
    }
    if (left < minLeft) left = minLeft;
    if (left > maxLeft) left = maxLeft;
    // If screen smaller than card+padding, just clamp to min.
    if (maxLeft < minLeft) left = minLeft;

    // Vertical:
    double top;
    if (flipBelow) {
      top = wordBottomY + (widget.compactAnchor ? -1 : tailHeight);
    } else {
      top = wordTopY - tailHeight - size.height;
    }
    // Final clamp: never let the popup draw above the safe-area top inset.
    if (top < minTop) top = minTop;
    if (widget.compactAnchor) {
      final maxTop =
          widget.screen.height - size.height - tailHeight - _kEdgePadding;
      if (maxTop >= minTop && top > maxTop) top = maxTop;
    }

    // Tail position: re-anchor to word center X relative to card.
    double tailCenterInCard = wordCenterX - left;
    if (tailCenterInCard < _kTailWidth / 2 + 6) {
      tailCenterInCard = _kTailWidth / 2 + 6;
    }
    if (tailCenterInCard > size.width - _kTailWidth / 2 - 6) {
      tailCenterInCard = size.width - _kTailWidth / 2 - 6;
    }

    return Positioned(
      left: left,
      top: top,
      child: TapRegion(
        onTapOutside: (_) => widget.onTapOutside(),
        child: SizedBox(
          width: size.width,
          height: size.height + tailHeight - _kPopupStrokeWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (!flipBelow) Positioned(left: 0, top: 0, child: card),
              if (flipBelow)
                Positioned(
                  left: 0,
                  top: tailHeight - _kPopupStrokeWidth,
                  child: card,
                ),
              // Tail.
              Positioned(
                left: tailCenterInCard - _kTailWidth / 2,
                top: flipBelow ? 0 : size.height - _kPopupStrokeWidth,
                child: CustomPaint(
                  key: const ValueKey('word-popup-tail'),
                  size: Size(_kTailWidth, tailHeight),
                  painter: _TailPainter(
                    pointDown: !flipBelow,
                    fillColor: BlabColors.chatSurface,
                    strokeColor: _kPopupStroke,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({
    required this.pointDown,
    required this.fillColor,
    required this.strokeColor,
  });

  /// `true` = tail points downward (card sits above word).
  /// `false` = tail points upward (card sits below word).
  final bool pointDown;
  final Color fillColor;
  final Color strokeColor;

  /// The card and tail share an outline, so the joined base stays open.
  bool get drawsBaseEdge => false;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final fillPath = Path();
    if (pointDown) {
      fillPath.moveTo(0, 0);
      fillPath.lineTo(size.width, 0);
      fillPath.lineTo(size.width / 2, size.height);
    } else {
      fillPath.moveTo(0, size.height);
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(size.width / 2, 0);
    }
    fillPath.close();

    // Soft shadow to match card.
    canvas.drawShadow(fillPath, Colors.black.withValues(alpha: 0.15), 4, false);
    canvas.drawPath(fillPath, fillPaint);

    // Draw only the two sloping sides. The missing base edge lets the white
    // tail merge into the white card without an internal divider.
    final sidePath = Path();
    if (pointDown) {
      sidePath.moveTo(0, 0);
      sidePath.lineTo(size.width / 2, size.height);
      sidePath.lineTo(size.width, 0);
    } else {
      sidePath.moveTo(0, size.height);
      sidePath.lineTo(size.width / 2, 0);
      sidePath.lineTo(size.width, size.height);
    }
    canvas.drawPath(
      sidePath,
      Paint()
        ..color = strokeColor
        ..strokeWidth = _kPopupStrokeWidth
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) =>
      oldDelegate.pointDown != pointDown ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.strokeColor != strokeColor;
}
