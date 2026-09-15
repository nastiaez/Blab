import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reading_script.dart';
import 'auth_state.dart';
import 'profile_state.dart';

typedef FetchReadingScript = Future<String> Function();
typedef UpdateReadingScript = Future<String> Function(String value);

final fetchReadingScriptProvider = Provider<FetchReadingScript>((ref) {
  return ref.read(profileServiceProvider).fetchReadingScript;
});

final updateReadingScriptProvider = Provider<UpdateReadingScript>((ref) {
  return ref.read(profileServiceProvider).updateReadingScript;
});

class ReadingScriptNotifier extends Notifier<ReadingScript> {
  String? _userId;
  int _generation = 0;

  @override
  ReadingScript build() {
    _userId = ref.watch(currentUserIdProvider);
    final generation = ++_generation;
    if (_userId case final userId?) {
      unawaited(_hydrate(userId, generation));
    }
    return ReadingScript.native;
  }

  Future<void> _hydrate(String userId, int generation) async {
    try {
      final value = await ref.read(fetchReadingScriptProvider)();
      if (generation != _generation || userId != _userId) return;
      state = readingScriptFromWire(value);
    } catch (_) {
      // Native is the safe default while the account preference is unavailable.
    }
  }

  Future<void> set(ReadingScript value) async {
    final userId = _userId;
    if (userId == null) throw StateError('not_signed_in');
    final previous = state;
    try {
      final saved = await ref.read(updateReadingScriptProvider)(value.wire);
      if (_userId != userId) return;
      state = readingScriptFromWire(saved);
      ref.invalidate(currentProfileProvider);
    } catch (_) {
      if (_userId == userId) state = previous;
      rethrow;
    }
  }
}

final readingScriptProvider =
    NotifierProvider<ReadingScriptNotifier, ReadingScript>(
      ReadingScriptNotifier.new,
    );
