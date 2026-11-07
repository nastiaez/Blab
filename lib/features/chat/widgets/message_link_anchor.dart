import 'package:flutter/material.dart';

/// Live geometry shared by contextual links and the existing message panels.
class MessageLinkAnchor extends InheritedWidget {
  const MessageLinkAnchor({
    super.key,
    this.bubble,
    this.viewport,
    required super.child,
  });
  final Rect? Function()? bubble;
  final Rect? Function()? viewport;
  static Rect? bubbleOf(BuildContext context) {
    Rect? result;
    context.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is MessageLinkAnchor && widget.bubble != null) {
        result = widget.bubble!();
        return false;
      }
      return true;
    });
    return result;
  }

  static Rect? Function()? viewportOf(BuildContext context) {
    Rect? Function()? result;
    context.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is MessageLinkAnchor && widget.viewport != null) {
        result = widget.viewport;
        return false;
      }
      return true;
    });
    return result;
  }

  @override
  bool updateShouldNotify(MessageLinkAnchor oldWidget) => true;
}
