import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_config.dart';
import '../data/app_channel.dart';
import 'account_deletion_recovery.dart';
import 'account_transition_gate.dart';

/// Thrown when the user cancels a social sign-in flow.
class SocialSignInCancelled implements Exception {
  const SocialSignInCancelled();
}

class SupabaseAuthService {
  SupabaseAuthService(this._client);

  final SupabaseClient _client;
  final AccountDeletionRecovery _deletionRecovery = AccountDeletionRecovery();

  GoTrueClient get _auth => _client.auth;

  User? get currentUser => _auth.currentUser;

  Session? get currentSession => _auth.currentSession;

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
    String interfaceLanguage = 'en',
  }) {
    return AccountTransitionGate.run(
      () => _auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'name': name.trim(),
          'interface_language': interfaceLanguage,
          if (name.trim().isEmpty) 'onboarding_name_blank': true,
        },
      ),
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return AccountTransitionGate.run(
      () => _auth.signInWithPassword(email: email.trim(), password: password),
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: '${AppChannel.scheme}://auth/reset',
    );
  }

  /// PRD US-004 follow-through: called from the reset screen after the
  /// recovery deep link has installed a session on the client.
  Future<UserResponse> updatePassword(String newPassword) {
    return AccountTransitionGate.run(
      () => _auth.updateUser(UserAttributes(password: newPassword)),
    );
  }

  /// Reauthenticates an email/password user immediately before changing the
  /// credential. Social-only accounts must not silently gain a password.
  Future<UserResponse> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => AccountTransitionGate.run(
    () => _changePasswordUnlocked(
      currentPassword: currentPassword,
      newPassword: newPassword,
    ),
  );

  Future<UserResponse> _changePasswordUnlocked({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = currentUser?.email;
    if (email == null) {
      throw const AuthException('Not signed in');
    }
    if (!hasPasswordIdentity) {
      throw const AuthException('Password sign-in is not enabled');
    }
    await _auth.signInWithPassword(email: email, password: currentPassword);
    return _auth.updateUser(UserAttributes(password: newPassword));
  }

  /// PRD US-039. Sends a confirmation email to the NEW address; the
  /// account email only switches after the user taps the link in that
  /// email. Old email keeps signing in until then. With "Secure email
  /// change" enabled (default), Supabase also sends a notice to the
  /// current email.
  Future<UserResponse> updateEmail(String newEmail) {
    return AccountTransitionGate.run(
      () => _auth.updateUser(
        UserAttributes(email: newEmail.trim()),
        emailRedirectTo: '${AppChannel.scheme}://auth/email-changed',
      ),
    );
  }

  Future<void> signOut() => AccountTransitionGate.run(_signOutUnlocked);

  Future<void> _signOutUnlocked() async {
    await _auth.signOut();
    try {
      final google = GoogleSignIn(
        serverClientId: SupabaseConfig.googleWebClientId,
      );
      if (await google.isSignedIn()) {
        await google.signOut();
      }
    } catch (_) {
      // Best-effort — Google sign-out failure shouldn't block Supabase sign-out.
    }
  }

  static bool isRevokedSessionError(Object error) {
    if (error is AuthRetryableFetchException) return false;
    if (error is! AuthException) return false;
    final message = error.message.toLowerCase();
    return message.contains('refresh token') &&
        (message.contains('not found') || message.contains('invalid'));
  }

  /// Native Google Sign-In → returns idToken → exchanges with Supabase
  /// via `signInWithIdToken`. Throws [SocialSignInCancelled] if the user
  /// dismisses the picker.
  Future<AuthResponse> signInWithGoogle() =>
      AccountTransitionGate.run(_signInWithGoogleUnlocked);

  Future<AuthResponse> _signInWithGoogleUnlocked() async {
    final google = GoogleSignIn(
      serverClientId: SupabaseConfig.googleWebClientId,
    );
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

  Future<AuthResponse> signInWithApple() =>
      AccountTransitionGate.run(_signInWithAppleUnlocked);

  Future<AuthResponse> _signInWithAppleUnlocked() async {
    final rawNonce = _auth.generateRawNonce();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );
      final token = credential.identityToken;
      if (token == null) {
        throw const AuthException('Apple returned no identity token');
      }
      final response = await _auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: token,
        nonce: rawNonce,
      );
      // Apple returns a name only on first authorization. Never replace a saved name.
      final name = [
        credential.givenName,
        credential.familyName,
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
      final existingName = response.user?.userMetadata?['full_name'] as String?;
      if (name.isNotEmpty && (existingName == null || existingName.isEmpty)) {
        try {
          await _auth.updateUser(UserAttributes(data: {'full_name': name}));
        } catch (_) {
          // Confirm name remains editable; metadata failure cannot undo authentication.
        }
      }
      return response;
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const SocialSignInCancelled();
      }
      rethrow;
    }
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
  Future<void> deleteAccount({
    String? password,
    required Future<void> Function(String owner) clearLocalData,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (await reconcilePendingDeletion(clearLocalData: clearLocalData)) return;
    if (user == null || email == null || _auth.currentUser?.id != user.id) {
      throw const AuthException('Not signed in');
    }
    if (password != null && password.isNotEmpty) {
      await signIn(email: email, password: password);
    }
    final receipt = await _deletionRecovery.begin(user.id);
    final accessToken = _auth.currentSession?.accessToken;
    if (_auth.currentUser?.id != user.id || accessToken == null) {
      throw const AuthException('Not signed in');
    }
    try {
      final res = await _client.functions.invoke(
        'delete-account',
        headers: {'Authorization': 'Bearer $accessToken'},
        body: {'deletion_receipt': receipt},
      );
      if (res.status != 200) {
        final body = res.data;
        final code = body is Map ? body['error']?.toString() : null;
        throw Exception(code ?? 'delete_failed');
      }
    } catch (_) {
      // A response can be lost after commit. Only the atomic receipt, never
      // an ordinary network/Auth error, authorizes local erasure.
      try {
        if (await reconcilePendingDeletion(clearLocalData: clearLocalData)) {
          return;
        }
      } catch (_) {
        /* Preserve marker and original failure for retry. */
      }
      rethrow;
    }
    await _finishLocalDeletion(user.id, clearLocalData);
    await _deletionRecovery.forget(owner: user.id, receipt: receipt);
  }

  Future<void> _finishLocalDeletion(
    String owner,
    Future<void> Function(String owner) clearLocalData,
  ) => AccountTransitionGate.run(() async {
    if (_auth.currentUser?.id != null && _auth.currentUser?.id != owner) {
      throw StateError('deletion_owner_changed');
    }
    try {
      await clearLocalData(owner);
    } finally {
      // Owner check and SDK local-session removal execute without an await
      // between them. Managed sign-ins cannot interleave with this section.
      if (_auth.currentUser?.id == owner) {
        await _auth.signOut(scope: SignOutScope.local);
      }
    }
  });

  Future<bool> reconcilePendingDeletion({
    required Future<void> Function(String owner) clearLocalData,
  }) => _deletionRecovery.reconcile(
    currentOwner: () => _auth.currentUser?.id,
    confirmed: (receipt) async {
      // Use anon authority even when the deleted user's bearer is revoked.
      final statusClient = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.publishableKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      try {
        return await statusClient
                .rpc(
                  'account_deletion_completed',
                  params: {'p_receipt': receipt},
                )
                .timeout(const Duration(seconds: 4)) ==
            true;
      } finally {
        await statusClient.dispose();
      }
    },
    erase: (owner) => _finishLocalDeletion(owner, clearLocalData),
  );

  /// Map a Supabase AuthException to a short, user-facing message.
  /// Inline error copy comes from PRD US-001…US-004.
  static String messageFor(Object error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      final code = error.code?.toLowerCase();
      if (code == 'invalid_credentials' ||
          msg.contains('invalid login') ||
          msg.contains('invalid credentials')) {
        return 'Email or password is incorrect';
      }
      if (code == 'email_exists' ||
          code == 'user_already_exists' ||
          msg.contains('already registered') ||
          msg.contains('user already') ||
          msg.contains('already exists')) {
        return 'An account with this email already exists';
      }
      if (code == 'weak_password' ||
          (msg.contains('password') && msg.contains('6'))) {
        return 'Password must be at least 6 characters';
      }
      if (code == 'email_address_invalid' ||
          msg.contains('email address is invalid') ||
          msg.contains('invalid email')) {
        return 'Enter a valid email address';
      }
      if (code == 'over_email_send_rate_limit' ||
          code == 'over_request_rate_limit' ||
          code == 'too_many_enrolled_mfa_factors' ||
          msg.contains('rate limit') ||
          msg.contains('too many requests')) {
        return 'Too many attempts. Try again later.';
      }
      if (msg.contains('email') && msg.contains('confirm')) {
        return 'Check your inbox to confirm your email';
      }
      return error.message;
    }
    return 'Something went wrong. Try again.';
  }

  static String passwordChangeMessageFor(Object error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login') ||
          message.contains('invalid credentials')) {
        return 'Current password is incorrect';
      }
      if (message.contains('same password') ||
          message.contains('different from the old')) {
        return 'Choose a different password';
      }
      if (message.contains('reauth') || message.contains('not signed in')) {
        return 'Please sign in again before changing your password';
      }
      if (message.contains('rate') || message.contains('too many')) {
        return 'Too many attempts. Try again later.';
      }
    }
    return 'Could not update your password. Try again.';
  }
}
