import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../state/connectivity_state.dart';
import '../state/app_update_state.dart';

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

/// Reserved update-notice slot; connection/access checks remain silent.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineAsync = ref.watch(onlineProvider);
    final connecting = ConnectionStatusScope.isConnecting(context);
    final update = ref.watch(appUpdateNoticeProvider).value;
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
            ? const SizedBox(width: double.infinity)
            : update != null
            ? _UpdateBar(key: ValueKey(update.destination), notice: update)
            : const SizedBox(width: double.infinity),
      ),
    );
  }
}

class _UpdateBar extends ConsumerStatefulWidget {
  const _UpdateBar({super.key, required this.notice});
  final AppUpdateNotice notice;
  @override
  ConsumerState<_UpdateBar> createState() => _UpdateBarState();
}

class _UpdateBarState extends ConsumerState<_UpdateBar> {
  bool _opening = false;
  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    var opened = false;
    try {
      opened = await ref.read(updateLinkLauncherProvider)(
        widget.notice.destination,
      );
    } catch (_) {
      // Keep the banner available to retry; do not navigate the chat.
    }
    if (!mounted) return;
    setState(() => _opening = false);
    if (!opened) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(context.l10n.updateOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: BlabColors.brandSoft,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final status = Semantics(
            liveRegion: true,
            child: Text(
              context.l10n.updateAvailable,
              style: const TextStyle(
                color: BlabColors.warmInk,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 20 / 14,
              ),
            ),
          );
          final action = Semantics(
            hint: context.l10n.updateAvailableHint,
            child: FilledButton(
              key: const ValueKey('update-download-button'),
              onPressed: _opening ? null : _open,
              style: FilledButton.styleFrom(
                foregroundColor: BlabColors.warmInk,
                backgroundColor: BlabColors.brand,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                tapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.standard,
                minimumSize: const Size(48, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .25,
                ),
              ),
              child: Text(context.l10n.updateAction),
            ),
          );
          final measure = TextPainter(
            text: TextSpan(
              text: context.l10n.updateAction,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: .25,
              ),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final actionWidth = measure.width + 24;
          measure.dispose();
          if (constraints.maxWidth <
              actionWidth + 12 + MediaQuery.textScalerOf(context).scale(100)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                status,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: status),
              const SizedBox(width: 12),
              action,
            ],
          );
        },
      ),
    ),
  );
}
