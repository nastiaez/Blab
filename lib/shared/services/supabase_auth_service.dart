import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_config.dart';

/// Thrown when the user cancels a social sign-in flow.
class SocialSignInCancelled implements Exception {
  const SocialSignInCancelled();
}

class SupabaseAuthService {
  SupabaseAuthService(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  User? get currentUser => _auth.currentUser;

  Session? get currentSession => _auth.currentSession;

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return _auth.signUp(
      email: email.trim(),
      password: password,
      data: {'name': name.trim()},
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'blab://auth/reset',
    );
  }

  /// PRD US-004 follow-through: called from the reset screen after the
  /// recovery deep link has installed a session on the client.
  Future<UserResponse> updatePassword(String newPassword) {
    return _auth.updateUser(UserAttributes(password: newPassword));
  }

  /// PRD US-039. Sends a confirmation email to the NEW address; the
  /// account email only switches after the user taps the link in that
  /// email. Old email keeps signing in until then. With "Secure email
  /// change" enabled (default), Supabase also sends a notice to the
  /// current email.
  Future<UserResponse> updateEmail(String newEmail) {
    return _auth.updateUser(
      UserAttributes(email: newEmail.trim()),
      emailRedirectTo: 'blab://auth/email-changed',
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      final google = GoogleSignIn(serverClientId: SupabaseConfig.googleWebClientId);
      if (await google.isSignedIn()) {
        await google.signOut();
      }
    } catch (_) {
      // Best-effort — Google sign-out failure shouldn't block Supabase sign-out.
    }
  }

  /// Native Google Sign-In → returns idToken → exchanges with Supabase
  /// via `signInWithIdToken`. Throws [SocialSignInCancelled] if the user
  /// dismisses the picker.
  Future<AuthResponse> signInWithGoogle() async {
    final google = GoogleSignIn(serverClientId: SupabaseConfig.googleWebClientId);
    final account = await google.signIn();
    if (account == null) {
      throw const SocialSignInCancelled();
    }
    final auth = await account.authentication;
    final idToken = auth.idToken;
    final accessToken = auth.accessToken;
    if (idToken == null) {
      throw const AuthException('No ID token returned from Google');
    }
    return _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  /// True when the user has an email/password identity. Google-only
  /// users will be false → UI should use email-typed confirmation.
  bool get hasPasswordIdentity {
    final identities = _auth.currentUser?.identities ?? const [];
    return identities.any((i) => i.provider == 'email');
  }

  /// PRD US-035. Re-verifies the password if [password] is provided,
  /// then invokes the `delete-account` edge function which removes
  /// the user from Supabase Auth. The server-side edge function
  /// validates the JWT, so omitting [password] (for social-login
  /// users) is still authenticated end-to-end.
  Future<void> deleteAccount({String? password}) async {
    final email = _auth.currentUser?.email;
    if (email == null) {
      throw const AuthException('Not signed in');
    }
    if (password != null && password.isNotEmpty) {
      await _auth.signInWithPassword(email: email, password: password);
    }

    final res = await _client.functions.invoke('delete-account');
    if (res.status != 200) {
      final body = res.data;
      final code = body is Map ? body['error']?.toString() : null;
      throw Exception(code ?? 'delete_failed');
    }
    await _auth.signOut();
  }

  /// Map a Supabase AuthException to a short, user-facing message.
  /// Inline error copy comes from PRD US-001…US-004.
  static String messageFor(Object error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login')) {
        return 'Email or password is incorrect';
      }
      if (msg.contains('already registered') ||
          msg.contains('user already') ||
          msg.contains('already exists')) {
        return 'An account with this email already exists';
      }
      if (msg.contains('password') && msg.contains('6')) {
        return 'Password must be at least 6 characters';
      }
      if (msg.contains('email') && msg.contains('confirm')) {
        return 'Check your inbox to confirm your email';
      }
      return error.message;
    }
    return 'Something went wrong. Try again.';
  }
}
