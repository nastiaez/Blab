import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/profile_service.dart';
import 'auth_state.dart';

final profileServiceProvider = Provider<ProfileService>(
  (ref) => ProfileService(ref.watch(supabaseClientProvider)),
);

final currentProfileProvider = FutureProvider<UserProfile>((ref) async {
  ref.watch(authSessionProvider);
  return ref.watch(profileServiceProvider).fetchCurrentProfile();
});

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
