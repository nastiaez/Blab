import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/blab_icon.dart';

/// Resolves the competing gestures inside a message bubble.
///
/// Normal bubbles leave child word taps enabled and reserve message actions for
/// long press. A horizontal swipe can start reply mode without interfering with
/// word taps. Retry remains a separate status-row action below the bubble.
class MessageInteractionTarget extends StatefulWidget {
  const MessageInteractionTarget({
    super.key,
    required this.isFailed,
    required this.onLongPress,
    required this.onFailedTap,
    this.onSwipeReply,
    required this.child,
  });

  final bool isFailed;
  final void Function(Rect bubbleRect, Offset pressPosition) onLongPress;
  final VoidCallback onFailedTap;
  final VoidCallback? onSwipeReply;
  final Widget child;

  @override
  State<MessageInteractionTarget> createState() =>
      _MessageInteractionTargetState();
}

class _MessageInteractionTargetState extends State<MessageInteractionTarget> {
  static const _replyTriggerDistance = 64.0;
  static const _horizontalDominanceRatio = 1.5;
  static const _maxVisualOffset = 56.0;

  double _dragDistance = 0;
  double _visualOffset = 0;
  Offset? _dragStartPosition;
  Offset? _dragLatestPosition;

  bool get _canSwipeReply => !widget.isFailed && widget.onSwipeReply != null;

  void _resetSwipe() {
    _dragStartPosition = null;
    _dragLatestPosition = null;
    if (_visualOffset == 0 && _dragDistance == 0) return;
    setState(() {
      _dragDistance = 0;
      _visualOffset = 0;
    });
  }

  void _startSwipe(DragStartDetails details) {
    _dragStartPosition = details.globalPosition;
    _dragLatestPosition = details.globalPosition;
  }

  void _updateSwipe(DragUpdateDetails details) {
    if (!_canSwipeReply) return;
    _dragLatestPosition = details.globalPosition;
    final delta = details.primaryDelta ?? 0;
    if (delta == 0) return;
    setState(() {
      _dragDistance += delta;
      _visualOffset = _dragDistance.clamp(-_maxVisualOffset, _maxVisualOffset);
    });
  }

  void _finishSwipe() {
    if (!_canSwipeReply) {
      _resetSwipe();
      return;
    }
    final dragDelta =
        (_dragLatestPosition ?? Offset.zero) -
        (_dragStartPosition ?? Offset.zero);
    final horizontalDistance = dragDelta.dx.abs();
    final verticalDistance = dragDelta.dy.abs();
    final shouldReply =
        horizontalDistance >= _replyTriggerDistance &&
        horizontalDistance >= verticalDistance * _horizontalDominanceRatio;
    _resetSwipe();
    if (shouldReply) widget.onSwipeReply!();
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    widget.onLongPress(rect, details.globalPosition);
  }

  @override
  Widget build(BuildContext context) {
    final replyOpacity = (_visualOffset.abs() / _replyTriggerDistance).clamp(
      0.0,
      1.0,
    );
    final replyAlignment = _visualOffset.isNegative
        ? Alignment.centerRight
        : Alignment.centerLeft;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: _handleLongPressStart,
        onTap: null,
        onHorizontalDragStart: _canSwipeReply ? _startSwipe : null,
        onHorizontalDragUpdate: _canSwipeReply ? _updateSwipe : null,
        onHorizontalDragEnd: _canSwipeReply ? (_) => _finishSwipe() : null,
        onHorizontalDragCancel: _canSwipeReply ? _resetSwipe : null,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: replyOpacity,
                  duration: const Duration(milliseconds: 80),
                  child: Align(
                    alignment: replyAlignment,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: BlabIcon(
                        name: 'long-arrow-up-left - 20',
                        size: 20,
                        color: BlabColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedSlide(
              offset: Offset(_visualOffset / 240, 0),
              duration: const Duration(milliseconds: 80),
              curve: Curves.easeOut,
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}

/// Extends swipe-to-reply across the full horizontal message row while
/// leaving taps and long presses to the bubble itself.
class MessageRowReplyTarget extends StatefulWidget {
  const MessageRowReplyTarget({
    super.key,
    required this.onSwipeReply,
    required this.child,
  });

  final VoidCallback? onSwipeReply;
  final Widget child;

  @override
  State<MessageRowReplyTarget> createState() => _MessageRowReplyTargetState();
}

class _MessageRowReplyTargetState extends State<MessageRowReplyTarget> {
  static const _replyTriggerDistance = 64.0;
  static const _horizontalDominanceRatio = 1.5;
  static const _maxVisualOffset = 56.0;

  double _dragDistance = 0;
  double _visualOffset = 0;
  Offset? _dragStartPosition;
  Offset? _dragLatestPosition;

  void _resetSwipe() {
    _dragStartPosition = null;
    _dragLatestPosition = null;
    if (_visualOffset == 0 && _dragDistance == 0) return;
    setState(() {
      _dragDistance = 0;
      _visualOffset = 0;
    });
  }

  void _startSwipe(DragStartDetails details) {
    _dragStartPosition = details.globalPosition;
    _dragLatestPosition = details.globalPosition;
  }

  void _updateSwipe(DragUpdateDetails details) {
    _dragLatestPosition = details.globalPosition;
    final delta = details.primaryDelta ?? 0;
    if (delta == 0) return;
    setState(() {
      _dragDistance += delta;
      _visualOffset = _dragDistance.clamp(-_maxVisualOffset, _maxVisualOffset);
    });
  }

  void _finishSwipe() {
    final dragDelta =
        (_dragLatestPosition ?? Offset.zero) -
        (_dragStartPosition ?? Offset.zero);
    final horizontalDistance = dragDelta.dx.abs();
    final verticalDistance = dragDelta.dy.abs();
    final shouldReply =
        horizontalDistance >= _replyTriggerDistance &&
        horizontalDistance >= verticalDistance * _horizontalDominanceRatio;
    _resetSwipe();
    if (shouldReply) widget.onSwipeReply?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onSwipeReply != null;
    final replyOpacity = (_visualOffset.abs() / _replyTriggerDistance).clamp(
      0.0,
      1.0,
    );
    final replyAlignment = _visualOffset.isNegative
        ? Alignment.centerRight
        : Alignment.centerLeft;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: enabled ? _startSwipe : null,
      onHorizontalDragUpdate: enabled ? _updateSwipe : null,
      onHorizontalDragEnd: enabled ? (_) => _finishSwipe() : null,
      onHorizontalDragCancel: enabled ? _resetSwipe : null,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: replyOpacity,
                duration: const Duration(milliseconds: 80),
                child: Align(
                  alignment: replyAlignment,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: BlabIcon(
                      name: 'long-arrow-up-left - 20',
                      size: 20,
                      color: BlabColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedSlide(
            offset: Offset(_visualOffset / 240, 0),
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
