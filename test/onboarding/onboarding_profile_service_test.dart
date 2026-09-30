import 'package:blab/shared/models/onboarding_stage.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile rows expose explicit onboarding progress', () {
    final profile = UserProfile.fromRow({
      'display_name': 'Nastia',
      'interface_language': 'uk',
      'known_languages': ['uk', 'de'],
      'primary_known_language': 'uk',
      'onboarding_version': 1,
      'onboarding_stage': 'language',
    });

    expect(profile.onboardingVersion, 1);
    expect(profile.onboardingStage, OnboardingStage.language);
    expect(profile.hasExplicitTranslationLanguage, isTrue);
  });

  test('legacy rows remain at intro and do not infer language completion', () {
    final profile = UserProfile.fromRow({
      'display_name': 'Legacy User',
      'interface_language': 'en',
      'known_languages': <String>[],
      'primary_known_language': null,
    });

    expect(profile.onboardingVersion, 0);
    expect(profile.onboardingStage, OnboardingStage.intro);
    expect(profile.hasExplicitTranslationLanguage, isFalse);
  });

  test('invalid legacy primary language is not treated as explicit', () {
    final missingFromKnown = UserProfile.fromRow({
      'display_name': 'Legacy User',
      'interface_language': 'en',
      'known_languages': ['de'],
      'primary_known_language': 'uk',
    });
    final unsupported = UserProfile.fromRow({
      'display_name': 'Legacy User',
      'interface_language': 'en',
      'known_languages': ['xx'],
      'primary_known_language': 'xx',
    });

    expect(missingFromKnown.hasExplicitTranslationLanguage, isFalse);
    expect(unsupported.hasExplicitTranslationLanguage, isFalse);
  });

  test('unknown server stages fail closed to intro', () {
    expect(onboardingStageFromWire('future-stage'), OnboardingStage.intro);
    expect(onboardingStageFromWire(null), OnboardingStage.intro);
  });

  test('onboarding RPC payload maps the returned progress', () {
    final progress = OnboardingProgress.fromJson({
      'version': 1,
      'stage': 'complete',
      'displayName': 'Nastia',
      'knownLanguages': ['uk', 'de'],
      'primaryKnownLanguage': 'de',
    });

    expect(progress.version, 1);
    expect(progress.stage, OnboardingStage.complete);
    expect(progress.displayName, 'Nastia');
    expect(progress.knownLanguages, ['uk', 'de']);
    expect(progress.primaryKnownLanguage, 'de');
  });
}
