import 'package:flutter/material.dart';

/// BLA-17 measured placement. Null explicitly means the unapproved overflow case.
({double top, bool below})? placeMessagePanels({
  required Rect viewport,
  required Rect bubble,
  required double height,
  required double afterVisibleLines,
  double? translationTop,
}) {
  if (bubble.bottom + 8 + height <= viewport.bottom &&
      bubble.bottom >= viewport.top) {
    return (top: bubble.bottom + 8, below: true);
  }
  if (bubble.top - 8 - height >= viewport.top &&
      bubble.top <= viewport.bottom) {
    return (top: bubble.top - 8 - height, below: false);
  }
  var top = afterVisibleLines;
  if (translationTop != null && top + height > translationTop - 8) {
    top = translationTop - 8 - height;
  }
  if (top < viewport.top || top + height > viewport.bottom) return null;
  return (top: top, below: false);
}

class AnchoredMessagePanels extends StatefulWidget {
  const AnchoredMessagePanels({
    super.key,
    required this.viewport,
    required this.bubble,
    required this.afterVisibleLines,
    this.translationTop,
    required this.actions,
    required this.reactions,
    required this.reactionWidth,
    this.hasReactions = true,
  });
  final Rect viewport;
  final Rect bubble;
  final double afterVisibleLines;
  final double? translationTop;
  final Widget actions;
  final Widget reactions;
  final double reactionWidth;
  final bool hasReactions;
  @override
  State<AnchoredMessagePanels> createState() => _AnchoredMessagePanelsState();
}

class _AnchoredMessagePanelsState extends State<AnchoredMessagePanels> {
  final _actionsKey = GlobalKey();
  double? _height;
  ({double top, bool below})? _placement;
  Rect? _stableViewport;
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _actionsKey.currentContext?.findRenderObject() as RenderBox?;
      if (mounted && box != null && box.hasSize && _height != box.size.height) {
        setState(() => _height = box.size.height);
      }
    });
    final pairHeight = (_height ?? 0) + (widget.hasReactions ? 8 + 44 : 0);
    if (_stableViewport != widget.viewport) {
      _placement = null;
      _stableViewport = widget.viewport;
    }
    final measuredPlacement = _height == null
        ? null
        : placeMessagePanels(
            viewport: widget.viewport,
            bubble: widget.bubble,
            height: pairHeight,
            afterVisibleLines: widget.afterVisibleLines,
            translationTop: widget.translationTop,
          );
    _placement ??= measuredPlacement;
    final placement = _placement;
    final width = widget.reactionWidth;
    final left = widget.bubble.center.dx - width / 2;
    final maxLeft = widget.viewport.right - width;
    final fitsWidth = maxLeft >= widget.viewport.left;
    final x = fitsWidth
        ? left.clamp(widget.viewport.left, maxLeft).toDouble()
        : 0.0;
    final actions = KeyedSubtree(key: _actionsKey, child: widget.actions);
    return Stack(
      children: [
        Positioned(
          top: placement?.top ?? widget.viewport.top,
          left: x,
          child: IgnorePointer(
            ignoring: placement == null || !fitsWidth,
            child: Opacity(
              opacity: placement == null || !fitsWidth ? 0 : 1,
              child: SizedBox(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      widget.bubble.center.dx > widget.viewport.center.dx
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: !widget.hasReactions
                      ? [actions]
                      : placement?.below == true
                      ? [widget.reactions, const SizedBox(height: 8), actions]
                      : [actions, const SizedBox(height: 8), widget.reactions],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
