import 'package:flutter/material.dart';

/// Global ScaffoldMessenger key. Used by router redirects + auth event
/// listeners to surface app-wide toasts (e.g. "Email changed ✓") even
/// when no current Scaffold is focused.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

const passiveAppSnackDuration = Duration(milliseconds: 2500);
const actionableAppSnackDuration = Duration(seconds: 4);

final NavigatorObserver appSnackRouteObserver = _AppSnackRouteObserver();

void dismissAppSnack() {
  appMessengerKey.currentState?.hideCurrentSnackBar();
}

class _AppSnackRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    dismissAppSnack();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    dismissAppSnack();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    dismissAppSnack();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    dismissAppSnack();
  }
}

void showAppSnack(
  String message, {
  SnackBarAction? action,
  Duration? duration,
}) {
  final m = appMessengerKey.currentState;
  if (m == null) return;
  dismissAppSnack();
  m.showSnackBar(
    SnackBar(
      content: Text(message),
      action: action,
      duration:
          duration ??
          (action != null
              ? actionableAppSnackDuration
              : passiveAppSnackDuration),
    ),
  );
}
