import 'package:flutter/material.dart';

/// Resolves the competing gestures inside a message bubble.
///
/// Normal bubbles leave child word taps enabled. Failed bubbles capture the
/// entire surface so clicking text or padding consistently opens send options.
class MessageInteractionTarget extends StatelessWidget {
  const MessageInteractionTarget({
    super.key,
    required this.isFailed,
    required this.onLongPress,
    required this.onTap,
    required this.onFailedTap,
    required this.child,
  });

  final bool isFailed;
  final VoidCallback onLongPress;
  final VoidCallback onTap;
  final VoidCallback onFailedTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        onTap: isFailed ? onFailedTap : onTap,
        child: IgnorePointer(ignoring: isFailed, child: child),
      ),
    );
  }
}
