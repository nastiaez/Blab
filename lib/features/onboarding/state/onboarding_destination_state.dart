import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/auth_state.dart';
import '../../../shared/state/interface_language.dart';
import '../../../shared/state/profile_state.dart';
import '../../invite/invite_continuation.dart';
import 'onboarding_destination.dart';
import 'onboarding_resolver.dart';
import 'onboarding_rollout_state.dart';

final onboardingDestinationProvider = FutureProvider<OnboardingDestination>((
  ref,
) async {
  ref.watch(authSessionProvider);
  final refreshEnabled = await ref.watch(
    onboardingRefreshEnabledProvider.future,
  );
  final session = ref.watch(supabaseAuthServiceProvider).currentSession;
  if (session == null) {
    return resolveOnboardingDestination(
      OnboardingResolverInput(
        bootstrapReady: true,
        refreshEnabled: refreshEnabled,
      ),
    );
  }

  if (!refreshEnabled) {
    final pendingInvite = await loadPendingInvite();
    return resolveOnboardingDestination(
      OnboardingResolverInput(
        bootstrapReady: true,
        refreshEnabled: false,
        signedIn: true,
        hasPendingInvite: pendingInvite != null,
      ),
    );
  }

  try {
    await applyPendingGuestInterfaceLanguageSync(
      activeUserId: () => ref.read(supabaseAuthServiceProvider).currentUser?.id,
      update: ref.read(updateInterfaceLanguageProvider),
    );
    if (ref.read(supabaseAuthServiceProvider).currentUser?.id !=
        session.user.id) {
      return OnboardingDestination.bootstrap;
    }
    ref.invalidate(interfaceLanguageProvider);
    final profile = await ref.watch(currentProfileProvider.future);
    if (ref.read(supabaseAuthServiceProvider).currentUser?.id !=
        session.user.id) {
      return OnboardingDestination.bootstrap;
    }
    final pendingInvite = await loadPendingInvite();
    return resolveOnboardingDestination(
      OnboardingResolverInput(
        bootstrapReady: true,
        refreshEnabled: refreshEnabled,
        signedIn: true,
        profileState: ProfileResolutionState.ready,
        account: AccountOnboardingState(
          version: profile.onboardingVersion,
          stage: profile.onboardingStage,
        ),
        hasPendingInvite: pendingInvite != null,
      ),
    );
  } catch (_) {
    return resolveOnboardingDestination(
      const OnboardingResolverInput(
        bootstrapReady: true,
        signedIn: true,
        profileState: ProfileResolutionState.retry,
      ),
    );
  }
});
