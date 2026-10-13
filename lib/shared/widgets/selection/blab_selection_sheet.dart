import 'package:flutter/material.dart';

/// Common typed Material modal presentation. Selection/persistence stays in
/// feature callers; required-choice routes keep their explicit barrier policy.
Future<T?> showBlabModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  Color? barrierColor,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = false,
  bool useRootNavigator = false,
  bool? showDragHandle,
  RouteSettings? routeSettings,
  AnimationStyle? sheetAnimationStyle,
}) => showModalBottomSheet<T>(
  context: context,
  builder: builder,
  backgroundColor: backgroundColor,
  barrierColor: barrierColor,
  elevation: elevation,
  shape: shape,
  clipBehavior: clipBehavior,
  constraints: constraints,
  isScrollControlled: isScrollControlled,
  isDismissible: isDismissible,
  enableDrag: enableDrag,
  useSafeArea: useSafeArea,
  useRootNavigator: useRootNavigator,
  showDragHandle: showDragHandle,
  routeSettings: routeSettings,
  sheetAnimationStyle: sheetAnimationStyle,
);
