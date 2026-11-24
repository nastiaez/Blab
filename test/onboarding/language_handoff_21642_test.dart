import 'package:blab/features/onboarding/state/language_draft.dart';
import 'package:blab/features/onboarding/state/onboarding_destination.dart';
import 'package:blab/features/onboarding/state/onboarding_destination_state.dart';
import 'package:blab/features/onboarding/state/onboarding_rollout_state.dart';
import 'package:blab/shared/models/onboarding_stage.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/services/supabase_auth_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/profile_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NoNetwork implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('NO NETWORK');
}

class Auth extends SupabaseAuthService {
  Auth(super.client);
  @override
  User get currentUser => User(
    id: 'A',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-11-23T15:00:00Z',
  );
  @override
  Session get currentSession => Session(
    accessToken: 'offline-fixture',
    tokenType: 'bearer',
    user: currentUser,
  );
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
}

class Profile extends ProfileService {
  Profile(super.client, {this.existingPrimary});
  final String? existingPrimary;
  bool completed = false;
  final calls = <String>[];
  final learningCalls = <String>[];
  UserProfile get value => UserProfile(
    displayName: 'Fixture',
    onboardingVersion: 1,
    onboardingStage: completed
        ? OnboardingStage.complete
        : OnboardingStage.language,
    primaryKnownLanguage: existingPrimary,
  );
  @override
  Future<OnboardingProgress> confirmOnboardingLanguages({
    required String learningLanguage,
    required String knownLanguage,
    int version = currentOnboardingVersion,
  }) async {
    learningCalls.add(learningLanguage);
    return confirmOnboardingLanguage(knownLanguage, version: version);
  }

  @override
  Future<OnboardingProgress> confirmOnboardingLanguage(
    String languageCode, {
    int version = currentOnboardingVersion,
  }) async {
    calls.add(languageCode);
    completed = true;
    return OnboardingProgress(
      version: 1,
      stage: OnboardingStage.complete,
      primaryKnownLanguage: languageCode,
    );
  }
}

class InvalidConfirmationProfile extends Profile {
  InvalidConfirmationProfile(super.client);
  @override
  Future<OnboardingProgress> confirmOnboardingLanguages({
    required String learningLanguage,
    required String knownLanguage,
    int version = currentOnboardingVersion,
  }) async => OnboardingProgress(
    version: version,
    stage: OnboardingStage.language,
    primaryKnownLanguage: knownLanguage,
  );
}

void main() {
  for (final primary in <String?>[null, 'uk']) {
    final label = primary ?? 'unset';
    test(
      'resolver consumes account-bound draft after name, existing primary wins: $label',
      () async {
        SharedPreferences.setMockInitialValues({});
        final draft = LanguageDraftStore();
        await draft.saveGuest(
          const LanguageDraft(learning: 'de', understood: 'en'),
        );
        await draft.bindNewAccount(userId: 'A', isNewAccount: true);
        final client = NoNetwork();
        final profile = Profile(client, existingPrimary: primary);
        final c = ProviderContainer(
          overrides: [
            supabaseAuthServiceProvider.overrideWithValue(Auth(client)),
            profileServiceProvider.overrideWithValue(profile),
            currentProfileProvider.overrideWith((ref) async => profile.value),
            onboardingRefreshEnabledProvider.overrideWith((ref) async => true),
          ],
        );
        addTearDown(c.dispose);
        expect(
          await c.read(onboardingDestinationProvider.future),
          OnboardingDestination.chats,
          reason:
              'successful atomic confirmation must resolve a terminal destination without a second external read',
        );
        await pumpEventQueue();
        expect(profile.calls, [primary ?? 'en']);
        expect(profile.learningCalls, ['de']);
        expect(await draft.pendingUnderstood('A'), isNull);
        expect((await draft.account('A')).learning, 'de');
        expect(
          await c.read(onboardingDestinationProvider.future),
          OnboardingDestination.chats,
        );
      },
    );
  }
  test(
    'non-terminal confirmation fails closed and retains pending choices',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = LanguageDraftStore();
      await store.saveGuest(
        const LanguageDraft(learning: 'de', understood: 'en'),
      );
      await store.bindNewAccount(userId: 'A', isNewAccount: true);
      final client = NoNetwork();
      final profile = InvalidConfirmationProfile(client);
      final c = ProviderContainer(
        overrides: [
          supabaseAuthServiceProvider.overrideWithValue(Auth(client)),
          profileServiceProvider.overrideWithValue(profile),
          currentProfileProvider.overrideWith((ref) async => profile.value),
          onboardingRefreshEnabledProvider.overrideWith((ref) async => true),
        ],
      );
      addTearDown(c.dispose);
      expect(
        await c.read(onboardingDestinationProvider.future),
        OnboardingDestination.retry,
      );
      expect(await store.pendingUnderstood('A'), 'en');
      expect((await store.account('A')).learning, 'de');
    },
  );
}
