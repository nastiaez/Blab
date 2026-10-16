import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../state/connectivity_state.dart';

/// Access refresh uses the same non-blocking banner slot as connectivity.
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

/// Slim system banner shown across post-login surfaces when the device loses
/// connectivity. PRD US-031.
///
/// Fixed 40 px tall, warm warning surface with 12 px w500 error text. Uses an
/// [AnimatedSize] + [AnimatedSwitcher] so it slides in / out at 200 ms.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  static const double bannerHeight = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineAsync = ref.watch(onlineProvider);
    final connecting = ConnectionStatusScope.isConnecting(context);
    // Treat "no data yet" as online so we don't flash the banner on cold
    // launch. We only consider an explicit `false` as offline.
    final isOffline = onlineAsync.maybeWhen(
      data: (v) => !v,
      orElse: () => false,
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: connecting || isOffline
            ? _Bar(key: ValueKey(connecting), connecting: connecting)
            : const SizedBox(width: double.infinity),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({super.key, required this.connecting});
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: connecting
          ? context.l10n.testAccessChecking
          : context.l10n.noConnection,
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        height: OfflineBanner.bannerHeight,
        color: connecting ? BlabColors.brand : BlabColors.brandSoft,
        alignment: Alignment.center,
        child: Text(
          connecting
              ? context.l10n.testAccessChecking
              : context.l10n.noConnection,
          style: TextStyle(
            color: connecting ? BlabColors.warmInk : BlabColors.error,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
