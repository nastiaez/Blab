import 'dart:convert';
import 'package:blab/shared/services/ios_communication.dart';
import 'package:blab/shared/services/push_token_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'stream_chat_session_test.dart' show identify, createClient, alice;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          IosCommunication.channel,
          (call) async => {
            'accountEpoch': 'epoch',
            'iosPresentation': 'blab_communication_v1',
          },
        );
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  for (final code in ['ok', 'PGRST202', '42501']) {
    test(
      'iOS registration $code has strict fallback and no caller identity',
      () async {
        final paths = <String>[];
        final client = createClient((r) async {
          paths.add(r.url.path);
          if (r.url.path.endsWith(
            '/rpc/register_communication_ios_push_token',
          )) {
            expect(jsonDecode(r.body), {
              'p_token': 'device-token',
              'p_previews_enabled': false,
              'p_account_epoch': 'epoch',
              'p_capability_version': 1,
            });
            if (code != 'ok') {
              return http.Response(
                jsonEncode({'code': code, 'message': 'unavailable'}),
                code == 'PGRST202' ? 404 : 403,
                headers: {'content-type': 'application/json'},
                request: r,
              );
            }
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
        final work = SupabasePushTokenRepository(
          client,
        ).register(token: 'device-token', previewsEnabled: false);
        if (code == '42501') {
          await expectLater(work, throwsA(isA<PostgrestException>()));
        } else {
          await work;
        }
        expect(paths.where((p) => p.contains('/rpc/')).toList(), [
          '/rest/v1/rpc/register_communication_ios_push_token',
          if (code == 'PGRST202') '/rest/v1/rpc/register_push_token',
        ]);
      },
    );
  }
  test('superseded native state cannot invoke legacy registration', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          IosCommunication.channel,
          (call) async => null,
        );
    final rpcPaths = <String>[];
    final client = createClient((r) async {
      if (r.url.path.contains('/rpc/')) rpcPaths.add(r.url.path);
      return http.Response(
        'null',
        200,
        headers: {'content-type': 'application/json'},
        request: r,
      );
    });
    addTearDown(client.dispose);
    await identify(client, alice);
    await expectLater(
      SupabasePushTokenRepository(
        client,
      ).register(token: 'device-token', previewsEnabled: false),
      throwsStateError,
    );
    expect(rpcPaths, isEmpty);
  });
}
