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
      .map((event) => event.session)
      .distinct((a, b) => a?.accessToken == b?.accessToken);
});

/// Convenience boolean — true once a session exists.
final isSignedInProvider = Provider<bool>((ref) {
  final session = ref.watch(authSessionProvider).value;
  return session != null;
});
