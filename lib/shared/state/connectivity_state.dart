import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dev/QA toggle: when `true`, the [onlineProvider] reports offline regardless
/// of real connectivity. Lets us demo PRD US-031 without airplane mode.
class ForceOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void set(bool value) => state = value;
}

final forceOfflineProvider =
    NotifierProvider<ForceOfflineNotifier, bool>(ForceOfflineNotifier.new);

/// Emits `true` when the device is online, `false` when offline.
///
/// PRD US-031. We use [Connectivity.onConnectivityChanged] from
/// `connectivity_plus`. A 200 ms debounce keeps the banner from flickering
/// during transient drops.
///
/// The [forceOfflineProvider] short-circuits the real state for demos —
/// when on, we emit `false` immediately and don't bother listening to the
/// platform.
final onlineProvider = StreamProvider<bool>((ref) async* {
  final forced = ref.watch(forceOfflineProvider);

  if (forced) {
    yield false;
    return;
  }

  final connectivity = Connectivity();

  bool resultsAreOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    // Any non-`none` result means we have some kind of connectivity.
    return results.any((r) => r != ConnectivityResult.none);
  }

  // Seed with the current state. If the platform call fails (e.g. in unit
  // tests where the plugin isn't wired up), default to online so we don't
  // surface a false offline banner.
  bool initial = true;
  try {
    final results = await connectivity.checkConnectivity();
    initial = resultsAreOnline(results);
  } catch (_) {
    initial = true;
  }
  yield initial;

  // Yield subsequent connectivity changes, debounced by 200 ms to ride out
  // transient drops without flickering the banner.
  Stream<bool> debounced(Stream<bool> source) async* {
    bool? last;
    await for (final value in source.transform(_DebounceTransformer<bool>(
        const Duration(milliseconds: 200)))) {
      if (value != last) {
        last = value;
        yield value;
      }
    }
  }

  yield* debounced(
    connectivity.onConnectivityChanged.map(resultsAreOnline),
  );
});

/// Synchronous boolean view of [onlineProvider]. Defaults to online while
/// connectivity is still unknown (the stream hasn't emitted yet) so a cold
/// first send isn't wrongly queued. The send path reads this to branch
/// without awaiting a stream. PRD US-031.
final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(onlineProvider).value ?? true,
);

/// Small debounce transformer used by [onlineProvider]. Emits the latest
/// value only after [duration] of silence.
class _DebounceTransformer<T> extends StreamTransformerBase<T, T> {
  _DebounceTransformer(this.duration);
  final Duration duration;

  @override
  Stream<T> bind(Stream<T> stream) {
    final controller = StreamController<T>();
    Timer? timer;
    T? lastValue;
    bool hasValue = false;

    final sub = stream.listen(
      (value) {
        lastValue = value;
        hasValue = true;
        timer?.cancel();
        timer = Timer(duration, () {
          if (hasValue && !controller.isClosed) {
            controller.add(lastValue as T);
          }
        });
      },
      onError: controller.addError,
      onDone: () {
        timer?.cancel();
        if (hasValue && !controller.isClosed) {
          controller.add(lastValue as T);
        }
        controller.close();
      },
      cancelOnError: false,
    );

    controller.onCancel = () {
      timer?.cancel();
      sub.cancel();
    };
    return controller.stream;
  }
}
