import '../../../shared/models/onboarding_stage.dart';
import 'onboarding_destination.dart';

const sessionLossBootstrapLocation = '/bootstrap';

class AccountOnboardingState {
  const AccountOnboardingState({required this.version, required this.stage});

  final int version;
  final OnboardingStage stage;
}

class OnboardingResolverInput {
  const OnboardingResolverInput({
    required this.bootstrapReady,
    this.refreshEnabled = true,
    this.callback = OnboardingCallback.none,
    this.signedIn = false,
    this.profileState = ProfileResolutionState.notRequired,
    this.account,
    this.hasPendingInvite = false,
  });

  final bool bootstrapReady;
  final bool refreshEnabled;
  final OnboardingCallback callback;
  final bool signedIn;
  final ProfileResolutionState profileState;
  final AccountOnboardingState? account;
  final bool hasPendingInvite;
}

OnboardingDestination resolveOnboardingDestination(
  OnboardingResolverInput input,
) {
  if (!input.bootstrapReady) return OnboardingDestination.bootstrap;

  switch (input.callback) {
    case OnboardingCallback.passwordRecoveryValid:
      return OnboardingDestination.resetPassword;
    case OnboardingCallback.passwordRecoveryInvalid:
      return OnboardingDestination.resetLinkExpired;
    case OnboardingCallback.emailChange:
      return OnboardingDestination.emailChange;
    case OnboardingCallback.none:
      break;
  }

  if (!input.refreshEnabled) {
    if (!input.signedIn) return OnboardingDestination.legacyAuth;
    if (input.hasPendingInvite) return OnboardingDestination.pendingInvite;
    return OnboardingDestination.chats;
  }

  if (!input.signedIn) return OnboardingDestination.welcome;
  if (input.profileState == ProfileResolutionState.loading ||
      input.profileState == ProfileResolutionState.notRequired) {
    return OnboardingDestination.bootstrap;
  }
  if (input.profileState == ProfileResolutionState.retry) {
    return OnboardingDestination.retry;
  }

  final account = input.account;
  if (account == null) return OnboardingDestination.retry;
  if (account.version < currentOnboardingVersion ||
      account.stage == OnboardingStage.intro) {
    return OnboardingDestination.welcome;
  }
  if (account.stage == OnboardingStage.name) {
    return OnboardingDestination.confirmName;
  }
  if (account.stage == OnboardingStage.language) {
    return OnboardingDestination.language;
  }
  if (input.hasPendingInvite) {
    return OnboardingDestination.pendingInvite;
  }
  return OnboardingDestination.chats;
}

bool isStaleAccountGeneration({
  required int requestGeneration,
  required int activeGeneration,
}) => requestGeneration != activeGeneration;

bool canAutoResumePendingInvite({
  required OnboardingDestination destination,
  required String? requestUserId,
  required String? activeUserId,
  required String routePath,
  required bool openInvite,
}) {
  if (requestUserId == null || requestUserId != activeUserId) return false;
  if (destination != OnboardingDestination.pendingInvite) return false;
  if (routePath.startsWith('/i/')) return false;
  if (routePath == '/bootstrap') return openInvite;
  if (routePath.startsWith('/onboarding/')) return false;
  if (routePath.startsWith('/auth')) {
    return openInvite && routePath == '/auth';
  }
  return true;
}
