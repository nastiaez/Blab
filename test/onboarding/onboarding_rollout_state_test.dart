import 'package:blab/features/onboarding/state/onboarding_rollout_state.dart';
import 'package:blab/shared/data/local_storage_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final savedRollout in <bool?>[null, false, true]) {
    test(
      'approved introduction survives legacy rollout $savedRollout offline',
      () async {
        SharedPreferences.setMockInitialValues({
          kCachedOnboardingRolloutKey: ?savedRollout,
        });
        // No Supabase client/network or preview build define is available.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        expect(
          await container.read(onboardingRefreshEnabledProvider.future),
          true,
        );
      },
    );
  }
}
