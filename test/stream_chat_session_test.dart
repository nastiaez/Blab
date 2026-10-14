import 'dart:async';
import 'dart:convert';

import 'package:blab/shared/services/stream_chat_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const alice = '00000000-0000-4000-8000-00000000000a';
const bob = '00000000-0000-4000-8000-00000000000b';
Future<void> identify(SupabaseClient client, String id) async {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final token =
      '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': id, 'role': 'authenticated', 'aud': 'authenticated', 'exp': now + 3600})}.fixture';
  await client.auth.setInitialSession(
    jsonEncode({
      'access_token': token,
      'refresh_token': 'fixture-$id',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': id,
        'aud': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-10-14T09:00:00Z',
      },
    }),
  );
}

SupabaseClient createClient(
  Future<http.Response> Function(http.Request) handler,
) => SupabaseClient(
  'http://fixture.invalid',
  'fixture-public-key',
  httpClient: MockClient(handler),
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);
void main() {
  test(
    'late token response cannot initialize another account connection',
    () async {
      final request = Completer<void>();
      final release = Completer<http.Response>();
      final client = createClient((_) {
        request.complete();
        return release.future;
      });
      await identify(client, alice);
      final session = StreamChatSession(client);
      final connection = session.connect();
      final rejection = expectLater(connection, throwsStateError);
      await request.future;
      await identify(client, bob);
      release.complete(
        http.Response(
          jsonEncode({
            'apiKey': 'fixture',
            'userId': alice,
            'token': 'fixture',
          }),
          200,
        ),
      );
      await rejection;
      expect(() => session.client, throwsStateError);
      await expectLater(session.connect(), throwsStateError);
      await session.dispose();
      await client.dispose();
    },
  );
  test(
    'transient credential failure is retryable instead of poisoning the session',
    () async {
      var attempts = 0;
      final client = createClient((_) async {
        attempts++;
        return http.Response('{}', 503);
      });
      await identify(client, alice);
      final session = StreamChatSession(client);
      await expectLater(session.connect(), throwsA(anything));
      await expectLater(session.connect(), throwsA(anything));
      expect(attempts, 2);
      await session.dispose();
      await client.dispose();
    },
  );
  test('disposed connection rejects an in-flight credential reply', () async {
    final request = Completer<void>();
    final release = Completer<http.Response>();
    final client = createClient((_) {
      request.complete();
      return release.future;
    });
    await identify(client, alice);
    final session = StreamChatSession(client);
    final connection = session.connect();
    final rejection = expectLater(connection, throwsStateError);
    await request.future;
    await session.dispose();
    release.complete(
      http.Response(
        jsonEncode({'apiKey': 'fixture', 'userId': alice, 'token': 'fixture'}),
        200,
      ),
    );
    await rejection;
    expect(() => session.client, throwsStateError);
    await client.dispose();
  });
}
