import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Anchors suggestions to the composer without consuming conversation space.
class MentionPickerOverlay extends StatefulWidget {
  const MentionPickerOverlay({super.key, required this.child, this.picker});
  final Widget child;
  final Widget? picker;

  @override
  State<MentionPickerOverlay> createState() => _MentionPickerOverlayState();
}

class _MentionPickerOverlayState extends State<MentionPickerOverlay> {
  final _controller = OverlayPortalController()..show();

  @override
  Widget build(BuildContext context) => OverlayPortal.overlayChildLayoutBuilder(
    controller: _controller,
    overlayChildBuilder: (context, info) {
      if (widget.picker == null) return const SizedBox.shrink();
      final anchor = MatrixUtils.transformPoint(
        info.childPaintTransform,
        Offset.zero,
      );
      final available = math.max(
        0.0,
        anchor.dy - MediaQuery.paddingOf(context).top - kToolbarHeight - 8,
      );
      return Positioned(
        left: anchor.dx,
        bottom: info.overlaySize.height - anchor.dy + 4,
        width: info.childSize.width,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: available),
          child: SingleChildScrollView(
            child: TextFieldTapRegion(child: widget.picker!),
          ),
        ),
      );
    },
    child: widget.child,
  );
}
