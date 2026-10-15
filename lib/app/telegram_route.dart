import 'package:flutter/material.dart';

class TelegramEaseOut extends Curve {
  const TelegramEaseOut();

  @override
  double transformInternal(double t) {
    final u = 1 - t;
    return 1 - u * u * u;
  }
}

Route<T> telegramRoute<T>(Widget page, {RouteSettings? settings}) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: const Duration(milliseconds: 150),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (context, animation, _, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (_, child) {
          final p = const TelegramEaseOut().transform(animation.value);
          return Transform.translate(
            offset: Offset(48 * (1 - p), 0),
            child: Opacity(opacity: p, child: child),
          );
        },
      );
    },
  );
}

class TelegramPage<T> extends Page<T> {
  const TelegramPage({required this.child, super.key, super.name});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) =>
      telegramRoute<T>(child, settings: this);
}
