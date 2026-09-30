import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/profile_state.dart';

typedef ConfirmOnboardingNameAction = Future<void> Function(String name);
typedef ConfirmOnboardingLanguageAction =
    Future<void> Function(String languageCode);

final confirmOnboardingNameActionProvider =
    Provider<ConfirmOnboardingNameAction>(
      (ref) => (name) async {
        await ref.read(profileServiceProvider).confirmOnboardingName(name);
        ref.invalidate(currentProfileProvider);
      },
    );

final confirmOnboardingLanguageActionProvider =
    Provider<ConfirmOnboardingLanguageAction>(
      (ref) => (languageCode) async {
        await ref
            .read(profileServiceProvider)
            .confirmOnboardingLanguage(languageCode);
        ref.invalidate(currentProfileProvider);
      },
    );
