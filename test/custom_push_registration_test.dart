import 'dart:convert';
import 'package:blab/shared/services/push_token_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'stream_chat_session_test.dart' show identify, createClient, alice;

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test(
    'new Android registers capability without caller-selected account',
    () async {
      final paths = <String>[];
      final client = createClient((r) async {
        paths.add(r.url.path);
        if (r.url.path.endsWith('/rpc/register_custom_android_push_token')) {
          expect(jsonDecode(r.body), {
            'p_token': 'device-token',
            'p_previews_enabled': false,
          });
        }
        return http.Response(
          'null',
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      });
      addTearDown(client.dispose);
      await identify(client, alice);
      await SupabasePushTokenRepository(
        client,
      ).register(token: 'device-token', previewsEnabled: false);
      expect(paths.where((p) => p.contains('/rpc/')).toList(), [
        '/rest/v1/rpc/register_custom_android_push_token',
      ]);
    },
  );
  test('only absent capability RPC permits old-server fallback', () async {
    final paths = <String>[];
    final client = createClient((r) async {
      paths.add(r.url.path);
      if (r.url.path.endsWith('/rpc/register_custom_android_push_token')) {
        return http.Response(
          '{"code":"PGRST202","message":"missing function"}',
          404,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }
      return http.Response(
        'null',
        200,
        headers: {'content-type': 'application/json'},
        request: r,
      );
    });
    addTearDown(client.dispose);
    await identify(client, alice);
    await SupabasePushTokenRepository(
      client,
    ).register(token: 'device-token', previewsEnabled: true);
    expect(paths.where((p) => p.contains('/rpc/')).toList(), [
      '/rest/v1/rpc/register_custom_android_push_token',
      '/rest/v1/rpc/register_push_token',
    ]);
  });
  test(
    'real capability registration rejection is not hidden by fallback',
    () async {
      final client = createClient(
        (r) async => http.Response(
          '{"code":"42501","message":"denied"}',
          403,
          headers: {'content-type': 'application/json'},
          request: r,
        ),
      );
      addTearDown(client.dispose);
      await identify(client, alice);
      await expectLater(
        SupabasePushTokenRepository(
          client,
        ).register(token: 'device-token', previewsEnabled: true),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
}
