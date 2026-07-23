import 'package:blab/shared/services/supabase_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _enabled = bool.fromEnvironment('RUN_LOCAL_SUPABASE_INTEGRATION');
const _url = String.fromEnvironment('SUPABASE_URL');
const _publicKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _serviceRoleKey = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');
const _oldPassword = 'Blab-local-123!';
const _newPassword = 'Blab-local-456!';

SupabaseClient _client(String key) => SupabaseClient(
  _url,
  key,
  authOptions: const AuthClientOptions(
    autoRefreshToken: false,
    authFlowType: AuthFlowType.implicit,
  ),
);

void main() {
  test(
    'local Supabase changes password only after current-password reauth',
    () async {
      expect(_url, isNotEmpty);
      expect(_publicKey, isNotEmpty);
      expect(_serviceRoleKey, isNotEmpty);

      final admin = _client(_serviceRoleKey);
      final account = _client(_publicKey);
      final oldPasswordCheck = _client(_publicKey);
      final newPasswordCheck = _client(_publicKey);
      final clients = [admin, account, oldPasswordCheck, newPasswordCheck];
      final email = 'l05-${DateTime.now().microsecondsSinceEpoch}@blab.test';
      String? userId;

      try {
        final signup = await SupabaseAuthService(
          account,
        ).signUp(name: 'L05 Integration', email: email, password: _oldPassword);
        userId = signup.user?.id;
        expect(userId, isNotNull);
        expect(signup.session, isNotNull);

        final auth = SupabaseAuthService(account);
        expect(auth.hasPasswordIdentity, isTrue);
        await expectLater(
          auth.changePassword(
            currentPassword: 'Wrong-local-123!',
            newPassword: _newPassword,
          ),
          throwsA(isA<AuthException>()),
        );

        await SupabaseAuthService(
          oldPasswordCheck,
        ).signIn(email: email, password: _oldPassword);
        await oldPasswordCheck.auth.signOut();

        await auth.changePassword(
          currentPassword: _oldPassword,
          newPassword: _newPassword,
        );

        await expectLater(
          SupabaseAuthService(
            oldPasswordCheck,
          ).signIn(email: email, password: _oldPassword),
          throwsA(isA<AuthException>()),
        );
        await SupabaseAuthService(
          newPasswordCheck,
        ).signIn(email: email, password: _newPassword);
        expect(newPasswordCheck.auth.currentUser?.id, userId);
      } finally {
        if (userId != null) {
          await admin.auth.admin.deleteUser(userId);
        }
        await Future.wait(clients.map((client) => client.dispose()));
      }
    },
    skip: _enabled
        ? false
        : 'Run through scripts/local_test.sh integration against local Supabase.',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
