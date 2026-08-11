import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_state.dart';

/// The signed-in user's known languages, with the empty-list case resolved
/// so downstream consumers never have to special-case it.
class KnownLanguages {
  const KnownLanguages({required this.codes, required this.primary});

  /// Never empty after fallback.
  final List<String> codes;

  /// Never null after fallback.
  final String primary;
}

/// Resolves the current user's known languages, falling back to their
/// interface language when they haven't set any yet.
final knownLanguagesProvider = FutureProvider<KnownLanguages>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile.knownLanguages.isEmpty) {
    return KnownLanguages(
      codes: [profile.interfaceLanguage],
      primary: profile.interfaceLanguage,
    );
  }
  final primary = profile.primaryKnownLanguage ?? profile.knownLanguages.first;
  return KnownLanguages(codes: profile.knownLanguages, primary: primary);
});
