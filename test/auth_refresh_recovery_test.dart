import 'dart:async';
import 'dart:convert';

import 'package:blab/app/router.dart';
import 'package:blab/main.dart';
import 'package:blab/shared/services/supabase_auth_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> identify(SupabaseClient client, String id) async {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final token =
      '${encode({'alg': 'HS256'})}.'
      '${encode({'sub': id, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.fixture';
  await client.auth.setInitialSession(
    jsonEncode({
      'access_token': token,
      'refresh_token': 'fixture-$id',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': id,
        'aud': 'authenticated',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': '2026-10-16T06:00:00Z',
      },
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('retryable server text cannot revoke a cached session', () {
    expect(
      SupabaseAuthService.isRevokedSessionError(
        AuthRetryableFetchException(
          message: 'Invalid Refresh Token: Refresh Token Not Found',
          statusCode: '503',
        ),
      ),
      isFalse,
    );
    expect(
      SupabaseAuthService.isRevokedSessionError(
        const AuthException('Invalid Refresh Token: Refresh Token Not Found'),
      ),
      isTrue,
    );
  });

  test('retryable auth errors preserve session state and later events', () async {
    final client = SupabaseClient(
      'https://fixture.invalid',
      'public-fixture',
      httpClient: MockClient((_) async => http.Response('', 204)),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final container = ProviderContainer(
      overrides: [supabaseClientProvider.overrideWithValue(client)],
    );
    final observed = <AsyncValue<Session?>>[];
    container.listen(authSessionProvider, (_, next) => observed.add(next));
    addTearDown(() async {
      container.dispose();
      await client.dispose();
    });
    await identify(client, 'alice');
    await container.read(authSessionProvider.future);
    observed.clear();
    for (final status in <String?>[null, '503']) {
      // Exercise the SDK's actual broadcast stream, not a replacement provider.
      // ignore: invalid_use_of_internal_member
      client.auth.notifyException(
        AuthRetryableFetchException(statusCode: status),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authSessionProvider).hasError, isFalse);
      expect(container.read(authSessionProvider).value?.user.id, 'alice');
      expect(container.read(isSignedInProvider), isTrue);
      expect(container.read(currentUserIdProvider), 'alice');
    }
    expect(observed, isEmpty);
    await identify(client, 'bob');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authSessionProvider).value?.user.id, 'bob');
    await client.auth.signOut(scope: SignOutScope.local);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authSessionProvider).value, isNull);
    expect(container.read(isSignedInProvider), isFalse);
    expect(container.read(currentUserIdProvider), isNull);
  });

  test('unexpected auth errors are not swallowed', () async {
    final client = SupabaseClient(
      'https://fixture.invalid',
      'public-fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final container = ProviderContainer(
      overrides: [supabaseClientProvider.overrideWithValue(client)],
    );
    container.listen(authSessionProvider, (_, _) {});
    addTearDown(() async {
      container.dispose();
      await client.dispose();
    });
    await identify(client, 'alice');
    await container.read(authSessionProvider.future);
    final error = StateError('unexpected auth failure');
    // ignore: invalid_use_of_internal_member
    client.auth.notifyException(error);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authSessionProvider).error, same(error));
  });

  testWidgets('app does not report retryable auth stream failures as crashes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://fixture.invalid',
      anonKey: 'public-fixture',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
    );
    blabRouter.go('/dev');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [onlineProvider.overrideWith((ref) => Stream.value(false))],
        child: const BlabApp(),
      ),
    );
    await tester.pumpAndSettle();
    // ignore: invalid_use_of_internal_member
    Supabase.instance.client.auth.notifyException(
      AuthRetryableFetchException(),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Blab — dev menu'), findsOneWidget);
    final unexpected = StateError('unexpected auth failure');
    // ignore: invalid_use_of_internal_member
    Supabase.instance.client.auth.notifyException(unexpected);
    await tester.pump();
    expect(tester.takeException(), same(unexpected));
    await tester.pumpWidget(const SizedBox.shrink());
    await Supabase.instance.dispose();
  });
}
