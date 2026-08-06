import 'package:flutter/material.dart';

/// Resolves the competing gestures inside a message bubble.
///
/// Normal bubbles leave child word taps enabled and reserve message actions for
/// long press. A horizontal swipe can start reply mode without interfering with
/// word taps. Failed bubbles capture the entire surface so clicking text or
/// padding consistently opens send options.
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
  final VoidCallback onLongPress;
  final VoidCallback onFailedTap;
  final VoidCallback? onSwipeReply;
  final Widget child;

  @override
  State<MessageInteractionTarget> createState() =>
      _MessageInteractionTargetState();
}

class _MessageInteractionTargetState extends State<MessageInteractionTarget> {
  static const _replyTriggerDistance = 52.0;
  static const _maxVisualOffset = 56.0;

  double _dragDistance = 0;
  double _visualOffset = 0;

  bool get _canSwipeReply => !widget.isFailed && widget.onSwipeReply != null;

  void _resetSwipe() {
    if (_visualOffset == 0 && _dragDistance == 0) return;
    setState(() {
      _dragDistance = 0;
      _visualOffset = 0;
    });
  }

  void _updateSwipe(DragUpdateDetails details) {
    if (!_canSwipeReply) return;
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
    final shouldReply = _dragDistance.abs() >= _replyTriggerDistance;
    _resetSwipe();
    if (shouldReply) widget.onSwipeReply!();
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
        onLongPress: widget.onLongPress,
        onTap: widget.isFailed ? widget.onFailedTap : null,
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
                      child: Icon(
                        Icons.reply,
                        size: 22,
                        color: Color(0xFF5B6BFF),
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
              child: IgnorePointer(
                ignoring: widget.isFailed,
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
