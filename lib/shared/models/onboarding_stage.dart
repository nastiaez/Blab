const currentOnboardingVersion = 1;

enum OnboardingStage { intro, name, language, complete }

OnboardingStage onboardingStageFromWire(String? value) {
  return switch (value) {
    'name' => OnboardingStage.name,
    'language' => OnboardingStage.language,
    'complete' => OnboardingStage.complete,
    _ => OnboardingStage.intro,
  };
}

String onboardingStageToWire(OnboardingStage stage) => stage.name;

class OnboardingProgress {
  const OnboardingProgress({
    required this.version,
    required this.stage,
    this.displayName,
    this.knownLanguages = const [],
    this.primaryKnownLanguage,
  });

  factory OnboardingProgress.fromJson(Map<String, dynamic> json) {
    return OnboardingProgress(
      version: (json['version'] as num?)?.toInt() ?? 0,
      stage: onboardingStageFromWire(json['stage'] as String?),
      displayName: json['displayName'] as String?,
      knownLanguages:
          (json['knownLanguages'] as List<dynamic>?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const [],
      primaryKnownLanguage: json['primaryKnownLanguage'] as String?,
    );
  }

  final int version;
  final OnboardingStage stage;
  final String? displayName;
  final List<String> knownLanguages;
  final String? primaryKnownLanguage;
}
