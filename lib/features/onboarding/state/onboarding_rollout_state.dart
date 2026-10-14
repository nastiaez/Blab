import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../../shared/data/local_storage_keys.dart';

typedef FetchOnboardingRefreshEnabled = Future<bool> Function();

// Private tester artifacts can preview US-001 without changing public rollout.
final onboardingRefreshPreviewProvider = Provider<bool>((ref) {
  return const bool.fromEnvironment('BLAB_ONBOARDING_REFRESH_PREVIEW');
});

final fetchOnboardingRefreshEnabledProvider =
    Provider<FetchOnboardingRefreshEnabled>((ref) {
      return () async {
        final value = await Supabase.instance.client.rpc(
          'is_feature_enabled',
          params: {'p_key': 'onboarding_auth_refresh'},
        );
        if (value is! bool) {
          throw StateError('invalid_feature_flag_response');
        }
        return value;
      };
    });

final onboardingRefreshEnabledProvider = FutureProvider<bool>((ref) async {
  if (ref.watch(onboardingRefreshPreviewProvider)) return true;
  SharedPreferences? preferences;
  try {
    preferences = await SharedPreferences.getInstance();
  } catch (_) {}
  final saved = preferences?.getBool(kCachedOnboardingRolloutKey);
  final fetch = ref.watch(fetchOnboardingRefreshEnabledProvider);
  if (saved != null) {
    unawaited(() async {
      try {
        final fresh = await fetch().timeout(const Duration(seconds: 8));
        if (!ref.mounted) return;
        final written = await preferences!.setBool(
          kCachedOnboardingRolloutKey,
          fresh,
        );
        if (written && ref.mounted && fresh != saved) ref.invalidateSelf();
      } catch (_) {}
    }());
    return saved;
  }
  try {
    final fresh = await fetch().timeout(const Duration(seconds: 8));
    try {
      await preferences?.setBool(kCachedOnboardingRolloutKey, fresh);
    } catch (_) {}
    return fresh;
  } catch (_) {
    return kDebugMode;
  }
});
