import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/connectivity_state.dart';

/// Slim system banner shown across post-login surfaces when the device loses
/// connectivity. PRD US-031.
///
/// Fixed 40 px tall, dark gray (`#333`) with 12 px w500 white text. Uses an
/// [AnimatedSize] + [AnimatedSwitcher] so it slides in / out at 200 ms.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  static const double bannerHeight = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineAsync = ref.watch(onlineProvider);
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
        child: isOffline ? const _Bar() : const SizedBox(width: double.infinity),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: "No internet connection. Messages will send when you're back online.",
      child: Container(
        width: double.infinity,
        height: OfflineBanner.bannerHeight,
        color: const Color(0xFF333333),
        alignment: Alignment.center,
        child: const Text(
          "No connection — messages will send when you're back online",
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
