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

/// Resolves the current user's known languages. Legacy accounts without a
/// saved choice get a stable English fallback; interface language must never
/// change translation targets.
final knownLanguagesProvider = FutureProvider<KnownLanguages>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile.knownLanguages.isEmpty) {
    return const KnownLanguages(codes: ['en'], primary: 'en');
  }
  final primary = profile.primaryKnownLanguage ?? profile.knownLanguages.first;
  return KnownLanguages(codes: profile.knownLanguages, primary: primary);
});
