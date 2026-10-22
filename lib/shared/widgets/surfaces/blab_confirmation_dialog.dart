import 'package:flutter/material.dart';

class BlabConfirmationDialog extends StatelessWidget {
  const BlabConfirmationDialog({
    super.key,
    this.title,
    this.scrollable = false,
    this.content,
    this.actions,
    this.backgroundColor,
    this.shape,
    this.actionsPadding,
    this.contentPadding,
    this.titlePadding,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: 40,
      vertical: 24,
    ),
  });
  final bool scrollable;
  final Widget? title, content;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final ShapeBorder? shape;
  final EdgeInsetsGeometry? actionsPadding, titlePadding;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsets insetPadding;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: title,
    scrollable: scrollable,
    content: content,
    actions: actions,
    backgroundColor: backgroundColor,
    shape: shape,
    actionsPadding: actionsPadding,
    contentPadding: contentPadding,
    titlePadding: titlePadding,
    insetPadding: insetPadding,
  );
}
