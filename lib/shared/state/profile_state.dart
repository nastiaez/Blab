import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/profile_service.dart';
import '../services/local_profile_cache.dart';
import 'auth_state.dart';

final profileServiceProvider = Provider<ProfileService>(
  (ref) => ProfileService(ref.watch(supabaseClientProvider)),
);

final currentProfileProvider = FutureProvider<UserProfile>((ref) async {
  ref.watch(authSessionProvider);
  final userId = ref.watch(currentUserIdProvider);
  final service = ref.watch(profileServiceProvider);
  if (userId == null) return service.fetchCurrentProfile();
  return cachedProfileFirst(
    cache: LocalProfileCache(userId),
    isCurrent: () => ref.mounted && ref.read(currentUserIdProvider) == userId,
    refresh: service.fetchCurrentProfile,
    changed: ref.invalidateSelf,
  );
}, retry: (_, _) => null);

typedef UpdateDisplayNameAction = Future<String> Function(String displayName);

final updateDisplayNameActionProvider = Provider<UpdateDisplayNameAction>((
  ref,
) {
  return (displayName) async {
    final saved = await ref
        .read(profileServiceProvider)
        .updateDisplayName(displayName);
    ref.invalidate(currentProfileProvider);
    return saved;
  };
});
