import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/supabase_config.dart';

typedef BackendReachabilityCheck = Future<bool> Function();

/// The app needs Supabase, not merely an attached network interface. The
/// health endpoint is public and contains no account data or secret headers.
final backendReachabilityCheckProvider = Provider<BackendReachabilityCheck>(
  (ref) => () async {
    try {
      final uri = Uri.parse('${SupabaseConfig.url}/auth/v1/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    }
  },
);

/// Dev/QA toggle: when `true`, the [onlineProvider] reports offline regardless
/// of real connectivity. Lets us demo PRD US-031 without airplane mode.
class ForceOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void set(bool value) => state = value;
}

final forceOfflineProvider = NotifierProvider<ForceOfflineNotifier, bool>(
  ForceOfflineNotifier.new,
);

/// Emits `true` when the device is online, `false` when offline.
///
/// PRD US-031. `connectivity_plus` tells us when an interface changes; a
/// bounded Supabase health probe verifies that the app's backend is actually
/// reachable. A periodic probe catches captive/offline Wi-Fi where the
/// interface itself never changes.
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
  final checkBackend = ref.watch(backendReachabilityCheckProvider);

  bool resultsAreOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    // Any non-`none` result means we have some kind of connectivity.
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<bool> evaluate(List<ConnectivityResult> results) async {
    if (!resultsAreOnline(results)) return false;
    return checkBackend();
  }

  // Seed with the current interface state, then verify Supabase before ever
  // reporting online. If the plugin is unavailable, the backend probe remains
  // authoritative.
  var currentResults = const <ConnectivityResult>[ConnectivityResult.other];
  try {
    currentResults = await connectivity.checkConnectivity();
  } catch (_) {
    // Keep the unknown-interface sentinel and rely on the backend probe.
  }
  final initial = await evaluate(currentResults);
  yield initial;

  final triggers = StreamController<List<ConnectivityResult>>();
  final subscription = connectivity.onConnectivityChanged.listen(
    (results) {
      currentResults = results;
      if (!triggers.isClosed) triggers.add(results);
    },
    onError: (_) {
      currentResults = const <ConnectivityResult>[];
      if (!triggers.isClosed) triggers.add(currentResults);
    },
  );
  var last = initial;
  // Recheck while offline so pending sends recover without an interface
  // change. Healthy clients do not poll the backend continuously.
  final timer = Timer.periodic(const Duration(seconds: 10), (_) {
    if (!last && !triggers.isClosed) triggers.add(currentResults);
  });
  try {
    await for (final results in triggers.stream.transform(
      _DebounceTransformer<List<ConnectivityResult>>(
        const Duration(milliseconds: 200),
      ),
    )) {
      final next = await evaluate(results);
      if (next != last) {
        last = next;
        yield next;
      }
    }
  } finally {
    timer.cancel();
    await subscription.cancel();
    await triggers.close();
  }
});

/// Synchronous boolean view of [onlineProvider]. Unknown is fail-closed: a
/// cold first send remains queued for the reconnect flush until Supabase has
/// been reached.
final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(onlineProvider).value ?? false,
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
