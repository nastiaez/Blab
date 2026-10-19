import 'package:flutter/material.dart';

/// Access-refresh state retained without user-facing connection notices.
class ConnectionStatusScope extends InheritedWidget {
  const ConnectionStatusScope({
    super.key,
    required this.connecting,
    required super.child,
  });
  final bool connecting;
  static bool isConnecting(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ConnectionStatusScope>()
          ?.connecting ??
      false;
  @override
  bool updateShouldNotify(ConnectionStatusScope oldWidget) =>
      connecting != oldWidget.connecting;
}

/// Reserved system-notice slot. Connection/access checks are silent (US-031).
/// Retained for the separately reviewed update-available notice.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
