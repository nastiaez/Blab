import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef FetchOnboardingRefreshEnabled = Future<bool> Function();

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
  try {
    return await ref.watch(fetchOnboardingRefreshEnabledProvider)();
  } catch (_) {
    return kDebugMode;
  }
});
