import 'package:flutter/material.dart';

/// Global ScaffoldMessenger key. Used by router redirects + auth event
/// listeners to surface app-wide toasts (e.g. "Email changed ✓") even
/// when no current Scaffold is focused.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void showAppSnack(String message, {SnackBarAction? action, Duration? duration}) {
  final m = appMessengerKey.currentState;
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(message),
      action: action,
      // Floating + close (×) button come from the global snackBarTheme.
      // Plain confirmations clear quickly; ones with an action (e.g. Undo)
      // linger a little longer so the action stays tappable.
      duration: duration ??
          (action != null
              ? const Duration(seconds: 4)
              : const Duration(milliseconds: 2200)),
    ),
  );
}
