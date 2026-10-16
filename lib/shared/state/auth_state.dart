import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_auth_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final supabaseAuthServiceProvider = Provider<SupabaseAuthService>(
  (ref) => SupabaseAuthService(ref.watch(supabaseClientProvider)),
);

/// Streams the current session. `null` when signed out.
final authSessionProvider = StreamProvider<Session?>((ref) {
  final auth = ref.watch(supabaseAuthServiceProvider);
  return auth.onAuthStateChange
      // US-031: transport failures are not account/session transitions. Keep
      // the last session until a real auth event (including sign-out) arrives.
      .handleError(
        (Object _, StackTrace _) {},
        test: (error) => error is AuthRetryableFetchException,
      )
      .map((event) => event.session)
      .distinct((a, b) => a?.accessToken == b?.accessToken);
});

typedef ChangePasswordAction =
    Future<void> Function({
      required String currentPassword,
      required String newPassword,
    });

final hasPasswordIdentityProvider = Provider<bool>((ref) {
  ref.watch(authSessionProvider);
  return ref.watch(supabaseAuthServiceProvider).hasPasswordIdentity;
});

final changePasswordActionProvider = Provider<ChangePasswordAction>((ref) {
  final auth = ref.watch(supabaseAuthServiceProvider);
  return ({required currentPassword, required newPassword}) async {
    await auth.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  };
});

/// Convenience boolean — true once a session exists.
final isSignedInProvider = Provider<bool>((ref) {
  final session = ref.watch(authSessionProvider).value;
  return session != null;
});

/// Stable account identity for device-local stores that must never be shared
/// across sessions. The client fallback is available while the auth stream is
/// still loading its initial value.
final currentUserIdProvider = Provider<String?>((ref) {
  final session = ref.watch(authSessionProvider).value;
  if (session?.user.id case final id?) return id;
  try {
    return ref.watch(supabaseClientProvider).auth.currentUser?.id;
  } catch (_) {
    return null;
  }
});
