import 'package:blab/features/onboarding/state/onboarding_actions.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/models/onboarding_stage.dart';
import 'package:blab/shared/state/profile_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NoNetwork implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('NO NETWORK');
}

class SavedNameProfile extends ProfileService {
  SavedNameProfile() : super(NoNetwork());
  @override
  Future<OnboardingProgress> confirmOnboardingName(
    String name, {
    int version = 1,
  }) async =>
      const OnboardingProgress(version: 1, stage: OnboardingStage.language);
}

void main() {
  test(
    'name save leaves mounted form alive until its navigation callback',
    () async {
      var profileReads = 0;
      final container = ProviderContainer(
        overrides: [
          profileServiceProvider.overrideWithValue(SavedNameProfile()),
          currentProfileProvider.overrideWith((ref) async {
            profileReads++;
            return const UserProfile(displayName: 'Before save');
          }),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(currentProfileProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(currentProfileProvider.future);
      await container.read(confirmOnboardingNameActionProvider)('Local Review');
      await container.pump();
      expect(
        profileReads,
        1,
        reason: 'route owner refreshes only after delivering navigation',
      );
    },
  );
}
