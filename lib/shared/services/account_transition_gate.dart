import 'dart:async';

/// Serializes managed identity installation with deletion's local erase/logout.
abstract final class AccountTransitionGate {
  static Future<void> _tail = Future<void>.value();
  static Future<T> run<T>(Future<T> Function() operation) {
    final previous = _tail;
    final release = Completer<void>();
    _tail = release.future;
    return (() async {
      await previous;
      try {
        return await operation();
      } finally {
        release.complete();
      }
    })();
  }
}
