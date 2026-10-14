import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/local_storage_keys.dart';
import 'profile_service.dart';

/// Presentation snapshot only. It never authorizes server requests.
class LocalProfileCache {
  LocalProfileCache(this.userId) {
    _generations.putIfAbsent(userId, () => 0);
  }
  final String userId;
  static final _generations = <String, int>{};
  static void invalidateAll() {
    for (final userId in _generations.keys.toList()) {
      _generations[userId] = (_generations[userId] ?? 0) + 1;
    }
  }

  int get generation => _generations[userId] ?? 0;
  String get _key => '$kCachedProfileKeyPrefix$userId';
  Future<UserProfile?> read() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return null;
      final value = jsonDecode(raw);
      if (value is! Map ||
          value['schema'] != 1 ||
          value['userId'] != userId ||
          value['profile'] is! Map) {
        return null;
      }
      return UserProfile.fromRow(
        Map<String, dynamic>.from(value['profile'] as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> write(UserProfile value, {int? expectedGeneration}) async {
    final preferences = await SharedPreferences.getInstance();
    if (expectedGeneration != null && generation != expectedGeneration) {
      return false;
    }
    return preferences.setString(
      _key,
      jsonEncode({
        'schema': 1,
        'userId': userId,
        'profile': {
          'display_name': value.displayName,
          'interface_language': value.interfaceLanguage,
          'known_languages': value.knownLanguages,
          'primary_known_language': value.primaryKnownLanguage,
          'grammatical_form': value.grammaticalForm,
          'reading_script': value.readingScript.name == 'englishLetters'
              ? 'english_letters'
              : 'native',
          'onboarding_version': value.onboardingVersion,
          'onboarding_stage': value.onboardingStage.name,
        },
      }),
    );
  }

  Future<void> clear() async {
    _generations[userId] = generation + 1;
    await (await SharedPreferences.getInstance()).remove(_key);
  }
}

Future<UserProfile> cachedProfileFirst({
  required LocalProfileCache cache,
  required bool Function() isCurrent,
  required Future<UserProfile> Function() refresh,
  required void Function() changed,
}) async {
  final generation = cache.generation;
  final saved = await cache.read();
  if (!isCurrent() || cache.generation != generation) {
    throw StateError('account_changed');
  }
  var persisted = false;
  Future<UserProfile> fetch() async {
    final fresh = await refresh().timeout(const Duration(seconds: 8));
    if (!isCurrent() || cache.generation != generation) {
      throw StateError('account_changed');
    }
    try {
      persisted = await cache.write(fresh, expectedGeneration: generation);
    } catch (_) {}
    if (!isCurrent() || cache.generation != generation) {
      throw StateError('account_changed');
    }
    return fresh;
  }

  if (saved == null) return fetch();
  unawaited(() async {
    try {
      final fresh = await fetch();
      if (persisted &&
          isCurrent() &&
          cache.generation == generation &&
          !_sameProfile(saved, fresh)) {
        changed();
      }
    } catch (_) {
      /* Offline keeps the last presentation snapshot. */
    }
  }());
  return saved;
}

bool _sameProfile(UserProfile a, UserProfile b) =>
    a.displayName == b.displayName &&
    a.interfaceLanguage == b.interfaceLanguage &&
    a.primaryKnownLanguage == b.primaryKnownLanguage &&
    a.grammaticalForm == b.grammaticalForm &&
    a.readingScript == b.readingScript &&
    a.onboardingVersion == b.onboardingVersion &&
    a.onboardingStage == b.onboardingStage &&
    jsonEncode(a.knownLanguages) == jsonEncode(b.knownLanguages);
