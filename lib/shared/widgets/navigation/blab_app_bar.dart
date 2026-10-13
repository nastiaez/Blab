import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Blab's common chrome, backed by the framework AppBar without custom routing.
class BlabAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BlabAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle,
    this.backgroundColor,
    this.foregroundColor,
    this.surfaceTintColor,
    this.elevation,
    this.scrolledUnderElevation,
    this.leadingWidth,
    this.titleSpacing,
    this.toolbarHeight,
    this.shape,
    this.bottom,
    this.systemOverlayStyle,
    this.automaticallyImplyLeading = true,
  });
  final Widget? title, leading;
  final List<Widget>? actions;
  final bool? centerTitle;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor, foregroundColor, surfaceTintColor;
  final double? elevation,
      scrolledUnderElevation,
      leadingWidth,
      titleSpacing,
      toolbarHeight;
  final ShapeBorder? shape;
  final PreferredSizeWidget? bottom;
  final SystemUiOverlayStyle? systemOverlayStyle;
  @override
  Size get preferredSize => Size.fromHeight(
    (toolbarHeight ?? kToolbarHeight) + (bottom?.preferredSize.height ?? 0),
  );
  @override
  Widget build(BuildContext context) => AppBar(
    title: title,
    leading: leading,
    actions: actions,
    centerTitle: centerTitle,
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    surfaceTintColor: surfaceTintColor,
    elevation: elevation,
    scrolledUnderElevation: scrolledUnderElevation,
    leadingWidth: leadingWidth,
    titleSpacing: titleSpacing,
    toolbarHeight: toolbarHeight,
    shape: shape,
    bottom: bottom,
    systemOverlayStyle: systemOverlayStyle,
    automaticallyImplyLeading: automaticallyImplyLeading,
  );
}
