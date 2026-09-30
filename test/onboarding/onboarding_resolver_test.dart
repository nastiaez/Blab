import 'package:blab/features/onboarding/state/onboarding_destination.dart';
import 'package:blab/features/onboarding/state/onboarding_resolver.dart';
import 'package:blab/shared/models/onboarding_stage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const completeProfile = AccountOnboardingState(
    version: currentOnboardingVersion,
    stage: OnboardingStage.complete,
  );

  final cases =
      <
        ({
          String name,
          OnboardingResolverInput input,
          OnboardingDestination expected,
        })
      >[
        (
          name: 'waits for bootstrap',
          input: const OnboardingResolverInput(bootstrapReady: false),
          expected: OnboardingDestination.bootstrap,
        ),
        (
          name: 'valid recovery callback wins over ordinary routing',
          input: const OnboardingResolverInput(
            bootstrapReady: true,
            callback: OnboardingCallback.passwordRecoveryValid,
          ),
          expected: OnboardingDestination.resetPassword,
        ),
        (
          name: 'invalid recovery callback has its own destination',
          input: const OnboardingResolverInput(
            bootstrapReady: true,
            callback: OnboardingCallback.passwordRecoveryInvalid,
          ),
          expected: OnboardingDestination.resetLinkExpired,
        ),
        (
          name: 'email change callback retains acknowledgement flow',
          input: const OnboardingResolverInput(
            bootstrapReady: true,
            callback: OnboardingCallback.emailChange,
          ),
          expected: OnboardingDestination.emailChange,
        ),
        (
          name: 'signed out begins at welcome',
          input: const OnboardingResolverInput(bootstrapReady: true),
          expected: OnboardingDestination.welcome,
        ),
        (
          name: 'disabled refresh sends signed-out users to legacy auth',
          input: const OnboardingResolverInput(
            bootstrapReady: true,
            refreshEnabled: false,
          ),
          expected: OnboardingDestination.legacyAuth,
        ),
        (
          name: 'disabled refresh keeps signed-in users in the legacy app',
          input: const OnboardingResolverInput(
            bootstrapReady: true,
            refreshEnabled: false,
            signedIn: true,
          ),
          expected: OnboardingDestination.chats,
        ),
        (
          name: 'signed in waits for profile',
          input: const OnboardingResolverInput(
            bootstrapReady: true,
            signedIn: true,
            profileState: ProfileResolutionState.loading,
          ),
          expected: OnboardingDestination.bootstrap,
        ),
        (
          name: 'signed in profile failure has retry destination',
          input: const OnboardingResolverInput(
            bootstrapReady: true,
            signedIn: true,
            profileState: ProfileResolutionState.retry,
          ),
          expected: OnboardingDestination.retry,
        ),
        (
          name: 'legacy account starts refreshed introduction',
          input: const OnboardingResolverInput(
            bootstrapReady: true,
            signedIn: true,
            profileState: ProfileResolutionState.ready,
            account: AccountOnboardingState(
              version: 0,
              stage: OnboardingStage.complete,
            ),
          ),
          expected: OnboardingDestination.welcome,
        ),
        (
          name: 'intro stage opens welcome',
          input: const OnboardingResolverInput(
            bootstrapReady: true,
            signedIn: true,
            profileState: ProfileResolutionState.ready,
            account: AccountOnboardingState(
              version: currentOnboardingVersion,
              stage: OnboardingStage.intro,
            ),
          ),
          expected: OnboardingDestination.welcome,
        ),
        (
          name: 'name stage opens name confirmation',
          input: const OnboardingResolverInput(
            bootstrapReady: true,
            signedIn: true,
            profileState: ProfileResolutionState.ready,
            account: AccountOnboardingState(
              version: currentOnboardingVersion,
              stage: OnboardingStage.name,
            ),
          ),
          expected: OnboardingDestination.confirmName,
        ),
        (
          name: 'language stage opens translation language choice',
          input: const OnboardingResolverInput(
            bootstrapReady: true,
            signedIn: true,
            profileState: ProfileResolutionState.ready,
            account: AccountOnboardingState(
              version: currentOnboardingVersion,
              stage: OnboardingStage.language,
            ),
          ),
          expected: OnboardingDestination.language,
        ),
        (
          name: 'complete account resumes pending invite first',
          input: const OnboardingResolverInput(
            bootstrapReady: true,
            signedIn: true,
            profileState: ProfileResolutionState.ready,
            account: completeProfile,
            hasPendingInvite: true,
          ),
          expected: OnboardingDestination.pendingInvite,
        ),
        (
          name: 'complete account without invite opens chats',
          input: const OnboardingResolverInput(
            bootstrapReady: true,
            signedIn: true,
            profileState: ProfileResolutionState.ready,
            account: completeProfile,
          ),
          expected: OnboardingDestination.chats,
        ),
      ];

  for (final scenario in cases) {
    test(scenario.name, () {
      expect(resolveOnboardingDestination(scenario.input), scenario.expected);
    });
  }

  test('a newer account generation makes an older result stale', () {
    expect(
      isStaleAccountGeneration(requestGeneration: 4, activeGeneration: 5),
      isTrue,
    );
    expect(
      isStaleAccountGeneration(requestGeneration: 5, activeGeneration: 5),
      isFalse,
    );
  });

  test('saved invite resumes only for the same completed account', () {
    expect(
      canAutoResumePendingInvite(
        destination: OnboardingDestination.pendingInvite,
        requestUserId: 'bob',
        activeUserId: 'bob',
        routePath: '/chats',
        openInvite: false,
      ),
      isTrue,
    );
    expect(
      canAutoResumePendingInvite(
        destination: OnboardingDestination.confirmName,
        requestUserId: 'bob',
        activeUserId: 'bob',
        routePath: '/onboarding/name',
        openInvite: false,
      ),
      isFalse,
    );
    expect(
      canAutoResumePendingInvite(
        destination: OnboardingDestination.pendingInvite,
        requestUserId: 'bob',
        activeUserId: 'alice',
        routePath: '/chats',
        openInvite: false,
      ),
      isFalse,
    );
  });

  test(
    'bootstrap opens a pending invite but never claims it in background',
    () {
      expect(
        canAutoResumePendingInvite(
          destination: OnboardingDestination.pendingInvite,
          requestUserId: 'bob',
          activeUserId: 'bob',
          routePath: '/bootstrap',
          openInvite: true,
        ),
        isTrue,
      );
      expect(
        canAutoResumePendingInvite(
          destination: OnboardingDestination.pendingInvite,
          requestUserId: 'bob',
          activeUserId: 'bob',
          routePath: '/bootstrap',
          openInvite: false,
        ),
        isFalse,
      );
    },
  );
}
