import 'package:flutter/material.dart';

/// One native icon-action boundary. Icons and callback policy belong to the
/// caller; Flutter owns activation, focus, keyboard and accessibility.
class BlabIconButton extends StatelessWidget {
  const BlabIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.padding,
    this.constraints,
    this.splashRadius,
    this.iconSize,
    this.style,
    this.focusNode,
    this.autofocus = false,
  });
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final double? splashRadius, iconSize;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  @override
  Widget build(BuildContext context) => IconButton(
    icon: icon,
    onPressed: onPressed,
    tooltip: tooltip,
    color: color,
    padding: padding,
    constraints: constraints,
    splashRadius: splashRadius,
    iconSize: iconSize,
    style: style,
    focusNode: focusNode,
    autofocus: autofocus,
  );
}
