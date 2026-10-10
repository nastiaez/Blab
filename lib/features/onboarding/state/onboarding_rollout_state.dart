import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  try {
    return await ref.watch(fetchOnboardingRefreshEnabledProvider)();
  } catch (_) {
    return kDebugMode;
  }
});
