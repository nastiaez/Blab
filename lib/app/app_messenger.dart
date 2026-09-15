import 'package:flutter/material.dart';

import '../shared/widgets/blab_icon.dart';
import 'theme.dart';

/// Global ScaffoldMessenger key. Used by router redirects + auth event
/// listeners to surface app-wide feedback (e.g. "Email changed") even
/// when no current Scaffold is focused.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

const passiveAppSnackDuration = Duration(milliseconds: 2500);
const actionableAppSnackDuration = Duration(seconds: 4);
const appSnackSurfaceGap = 12.0;

final NavigatorObserver appSnackRouteObserver = _AppSnackRouteObserver();

int _appSnackGeneration = 0;

void dismissAppSnack() {
  _appSnackGeneration += 1;
  appMessengerKey.currentState?.hideCurrentSnackBar();
}

class _AppSnackRouteObserver extends NavigatorObserver {
  void _dismissAfterBuild() {
    final generationAtNavigation = _appSnackGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generationAtNavigation == _appSnackGeneration) {
        dismissAppSnack();
      }
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissAfterBuild();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissAfterBuild();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _dismissAfterBuild();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissAfterBuild();
  }
}

void showAppSnack(
  String message, {
  SnackBarAction? action,
  Duration? duration,
}) {
  final m = appMessengerKey.currentState;
  if (m == null) return;
  _appSnackGeneration += 1;
  m.hideCurrentSnackBar();
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

/// Shows passive success feedback as a calm, content-sized acknowledgement.
void showAppSuccessSnack(String message, {double bottomClearance = 0}) {
  final m = appMessengerKey.currentState;
  if (m == null) return;
  _appSnackGeneration += 1;
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      duration: passiveAppSnackDuration,
      showCloseIcon: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        bottomClearance + appSnackSurfaceGap,
      ),
      content: Align(
        alignment: Alignment.center,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFECE7E1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const BlabIcon(
                  key: Key('app-success-icon'),
                  name: 'check-circle - 20',
                  color: BlabColors.bubbleInk,
                  size: 20,
                ),
                Text(
                  message,
                  style: const TextStyle(
                    color: BlabColors.bubbleInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Presents destination feedback only after navigation observers have finished
/// dismissing feedback owned by the departing route.
void showAppSuccessSnackAfterNavigation(
  String message, {
  double bottomClearance = 0,
}) {
  WidgetsBinding.instance.endOfFrame.then((_) {
    showAppSuccessSnack(message, bottomClearance: bottomClearance);
  });
}
