import 'package:blab/features/onboarding/state/onboarding_rollout_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blab/shared/data/local_storage_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'offline cold entry keeps the last verified rollout instead of switching onboarding paths',
    () async {
      SharedPreferences.setMockInitialValues({
        kCachedOnboardingRolloutKey: false,
      });
      final container = ProviderContainer(
        overrides: [
          fetchOnboardingRefreshEnabledProvider.overrideWithValue(
            () async => throw StateError('offline'),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(
        await container.read(onboardingRefreshEnabledProvider.future),
        false,
      );
    },
  );
  test(
    'private preview opens onboarding without fetching public rollout',
    () async {
      var remoteCalls = 0;
      final container = ProviderContainer(
        overrides: [
          onboardingRefreshPreviewProvider.overrideWithValue(true),
          fetchOnboardingRefreshEnabledProvider.overrideWithValue(() async {
            remoteCalls++;
            throw StateError('offline');
          }),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(onboardingRefreshEnabledProvider.future),
        true,
      );
      expect(remoteCalls, 0);
    },
  );

  test('remote rollout value enables the refreshed resolver', () async {
    final container = ProviderContainer(
      overrides: [
        fetchOnboardingRefreshEnabledProvider.overrideWithValue(
          () async => true,
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(onboardingRefreshEnabledProvider.future), true);
  });

  test('remote rollout value can return users to legacy auth', () async {
    final container = ProviderContainer(
      overrides: [
        onboardingRefreshPreviewProvider.overrideWithValue(false),
        fetchOnboardingRefreshEnabledProvider.overrideWithValue(
          () async => false,
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(onboardingRefreshEnabledProvider.future),
      false,
    );
  });

  test('debug builds fail open so local QA remains reachable', () async {
    final container = ProviderContainer(
      overrides: [
        fetchOnboardingRefreshEnabledProvider.overrideWithValue(
          () async => throw StateError('offline'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(onboardingRefreshEnabledProvider.future), true);
  });
}
