import 'dart:async';
import 'dart:convert';
import 'package:blab/shared/services/supabase_auth_service.dart';
import 'package:blab/shared/services/local_account_data_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const oldId = '00000000-0000-4000-8000-00000000000a',
    newId = '00000000-0000-4000-8000-00000000000b';
String token(String id) {
  String enc(Object x) =>
      base64Url.encode(utf8.encode(jsonEncode(x))).replaceAll('=', '');
  return '${enc({'alg': 'HS256'})}.${enc({'sub': id, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.local-signature';
}

Map<String, dynamic> response(String id, String email) => {
  'access_token': token(id),
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'refresh-$id',
  'user': {
    'id': id,
    'email': email,
    'aud': 'authenticated',
    'app_metadata': {'provider': 'email'},
    'user_metadata': <String, dynamic>{},
    'created_at': '2026-11-03T00:00:00Z',
  },
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'cached_profile:$oldId': 'old private',
      'cached_profile:$newId': 'new private',
    }),
  );
  for (final bypass in [false, true]) {
    test(
      'owner-bound cleanup preserves new account, bypassManagedGate=$bypass',
      () async {
        final log = <String>[];
        String? deletionBearer;
        final client = SupabaseClient(
          'http://localhost',
          'local-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((r) async {
            if (r.url.path.endsWith('/token')) {
              final email = (jsonDecode(r.body) as Map)['email'] as String;
              log.add(email);
              return http.Response(
                jsonEncode(
                  response(email.startsWith('old') ? oldId : newId, email),
                ),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (r.url.path.endsWith('/delete-account')) {
              deletionBearer = r.headers['authorization'];
              return http.Response(
                '{"ok":true}',
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (r.url.path.endsWith('/logout')) return http.Response('', 204);
            throw StateError('unexpected ${r.url.path}');
          }),
        );
        addTearDown(client.dispose);
        final service = SupabaseAuthService(client);
        await service.signIn(
          email: 'old@test.invalid',
          password: 'local-password',
        );
        final expectedBearer =
            'Bearer ${client.auth.currentSession!.accessToken}';
        final started = Completer<void>(), release = Completer<void>();
        final deleting = service.deleteAccount(
          clearLocalData: (owner) async {
            expect(owner, oldId);
            started.complete();
            await release.future;
            await LocalAccountDataStore(
              clearNotifications: () async {},
            ).clearForOwner(owner);
          },
        );
        await started.future;
        final login = bypass
            ? client.auth.signInWithPassword(
                email: 'new@test.invalid',
                password: 'local-password',
              )
            : service.signIn(
                email: 'new@test.invalid',
                password: 'local-password',
              );
        if (bypass) {
          await login;
        } else {
          await Future<void>.delayed(Duration.zero);
          expect(log, ['old@test.invalid']);
        }
        release.complete();
        await deleting;
        await login;
        expect(client.auth.currentUser?.id, newId);
        expect(deletionBearer, expectedBearer);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('cached_profile:$oldId'), isNull);
        expect(prefs.getString('cached_profile:$newId'), 'new private');
      },
    );
  }
  test(
    'identity switch during server request cannot delete or sign out the new account',
    () async {
      final requested = Completer<void>(), respond = Completer<void>();
      String? bearer;
      var clears = 0;
      final client = SupabaseClient(
        'http://localhost',
        'local-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          if (r.url.path.endsWith('/token')) {
            final email = (jsonDecode(r.body) as Map)['email'] as String;
            return http.Response(
              jsonEncode(
                response(email.startsWith('old') ? oldId : newId, email),
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (r.url.path.endsWith('/delete-account')) {
            bearer = r.headers['authorization'];
            requested.complete();
            await respond.future;
            return http.Response(
              '{"ok":true}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (r.url.path.endsWith('/logout')) {
            throw StateError('must not sign out new account');
          }
          throw StateError('unexpected route');
        }),
      );
      addTearDown(client.dispose);
      final service = SupabaseAuthService(client);
      await service.signIn(email: 'old@test.invalid', password: 'local');
      final expectedBearer =
          'Bearer ${client.auth.currentSession!.accessToken}';
      final deleting = service.deleteAccount(
        clearLocalData: (_) async {
          clears++;
        },
      );
      await requested.future;
      await service.signIn(email: 'new@test.invalid', password: 'local');
      respond.complete();
      await expectLater(deleting, throwsStateError);
      expect(clears, 0);
      expect(client.auth.currentUser?.id, newId);
      expect(bearer, expectedBearer);
    },
  );
}
