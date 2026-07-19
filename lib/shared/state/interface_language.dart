import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/languages.dart';
import '../data/local_storage_keys.dart';
import 'auth_state.dart';
import 'profile_state.dart';

typedef FetchInterfaceLanguage = Future<String> Function();
typedef UpdateInterfaceLanguage = Future<String> Function(String languageCode);

final fetchInterfaceLanguageProvider = Provider<FetchInterfaceLanguage>((ref) {
  return ref.read(profileServiceProvider).fetchInterfaceLanguage;
});

final updateInterfaceLanguageProvider = Provider<UpdateInterfaceLanguage>((
  ref,
) {
  return ref.read(profileServiceProvider).updateInterfaceLanguage;
});

/// Account-scoped interface locale. English is always the default/fallback.
class InterfaceLanguageNotifier extends Notifier<BlabLanguage> {
  String? _userId;
  int _generation = 0;

  @override
  BlabLanguage build() {
    _userId = ref.watch(currentUserIdProvider);
    final generation = ++_generation;
    unawaited(_hydrate(_userId, generation));
    return interfaceLanguageForCode('en');
  }

  Future<void> _hydrate(String? userId, int generation) async {
    final preferences = await SharedPreferences.getInstance();
    final localCode = preferences.getString(
      interfaceLanguageStorageKey(userId),
    );
    if (generation != _generation) return;
    state = interfaceLanguageForCode(localCode);

    if (userId == null) return;
    try {
      final remoteCode = await ref.read(fetchInterfaceLanguageProvider)();
      if (generation != _generation || userId != _userId) return;
      final remote = interfaceLanguageForCode(remoteCode);
      state = remote;
      await preferences.setString(
        interfaceLanguageStorageKey(userId),
        remote.code,
      );
    } catch (_) {
      // The valid account-scoped cache remains usable while offline.
    }
  }

  Future<void> set(BlabLanguage language) async {
    final next = interfaceLanguageForCode(language.code);
    if (next.code != language.code) {
      throw ArgumentError.value(
        language.code,
        'language',
        'unsupported_locale',
      );
    }
    final previous = state;
    final userId = _userId;
    final preferences = await SharedPreferences.getInstance();
    if (userId == null) {
      state = next;
      await preferences.setString(
        interfaceLanguageStorageKey(userId),
        next.code,
      );
      return;
    }

    try {
      final saved = await ref.read(updateInterfaceLanguageProvider)(next.code);
      if (_userId != userId) return;
      state = interfaceLanguageForCode(saved);
      await preferences.setString(
        interfaceLanguageStorageKey(userId),
        state.code,
      );
    } catch (_) {
      if (_userId == userId) {
        state = previous;
      }
      rethrow;
    }
  }
}

final interfaceLanguageProvider =
    NotifierProvider<InterfaceLanguageNotifier, BlabLanguage>(
      InterfaceLanguageNotifier.new,
    );
