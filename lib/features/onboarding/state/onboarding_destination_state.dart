import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/auth_state.dart';
import '../../../shared/models/onboarding_stage.dart';
import 'language_draft.dart';
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
    // A proven new-account draft is consumed only at the existing, guarded
    // language stage. Existing profile preferences always win.
    final draftStore = ref.read(languageDraftStoreProvider);
    OnboardingProgress? savedProgress;
    final confirmed = await confirmBoundTranslationDraft(
      store: draftStore,
      userId: session.user.id,
      activeUserId: () => ref.mounted
          ? ref.read(supabaseAuthServiceProvider).currentUser?.id
          : null,
      eligible:
          profile.onboardingStage == OnboardingStage.language &&
          profile.onboardingVersion == currentOnboardingVersion,
      existingPrimary: LanguageDraft.supported(profile.primaryKnownLanguage)
          ? profile.primaryKnownLanguage
          : null,
      confirm: (code) async {
        await ref.read(profileServiceProvider).confirmOnboardingLanguage(code);
      },
      confirmLanguages: (learning, understood) async {
        final saved = await ref
            .read(profileServiceProvider)
            .confirmOnboardingLanguages(
              learningLanguage: learning,
              knownLanguage: understood,
            );
        if (saved.version != currentOnboardingVersion ||
            saved.stage != OnboardingStage.complete) {
          throw StateError('invalid_onboarding_confirmation');
        }
        savedProgress = saved;
      },
    );
    if (!ref.mounted ||
        ref.read(supabaseAuthServiceProvider).currentUser?.id !=
            session.user.id) {
      return OnboardingDestination.bootstrap;
    }
    final account = confirmed
        ? AccountOnboardingState(
            version: savedProgress!.version,
            stage: savedProgress!.stage,
          )
        : AccountOnboardingState(
            version: profile.onboardingVersion,
            stage: profile.onboardingStage,
          );
    final pendingInvite = await loadPendingInvite();
    if (!ref.mounted ||
        ref.read(supabaseAuthServiceProvider).currentUser?.id !=
            session.user.id) {
      return OnboardingDestination.bootstrap;
    }

    return resolveOnboardingDestination(
      OnboardingResolverInput(
        bootstrapReady: true,
        refreshEnabled: refreshEnabled,
        signedIn: true,
        profileState: ProfileResolutionState.ready,
        account: account,
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
