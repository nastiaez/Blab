import 'package:blab/features/onboarding/state/onboarding_rollout_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
