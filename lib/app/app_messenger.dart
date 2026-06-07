import 'package:flutter/material.dart';

/// Global ScaffoldMessenger key. Used by router redirects + auth event
/// listeners to surface app-wide toasts (e.g. "Email changed ✓") even
/// when no current Scaffold is focused.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void showAppSnack(String message, {SnackBarAction? action}) {
  final m = appMessengerKey.currentState;
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(content: Text(message), action: action));
}
