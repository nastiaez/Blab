import 'dart:convert';
import 'dart:typed_data';
import 'package:blab/shared/services/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const uid = '00000000-0000-4000-8000-00000000000a';
  late SupabaseClient client;
  late ProfileService service;
  late List<http.Request> requests;
  var rejectCommit = false;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    requests = [];
    rejectCommit = false;
    client = SupabaseClient(
      'https://unit.test',
      'anon',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        requests.add(r);
        if (r.url.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({
              'access_token': 'unit-token',
              'refresh_token': 'unit-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': uid,
                'aud': 'authenticated',
                'role': 'authenticated',
                'email': 'unit@example.test',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-11-07T00:00:00Z',
              },
            }),
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }
        if (r.url.path.contains('/rpc/update_my_avatar')) {
          if (rejectCommit) {
            return http.Response(
              '{"message":"rejected","code":"42501"}',
              403,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            'null',
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }
        if (r.url.path.contains('/object/sign/')) {
          return http.Response(
            '{"signedURL":"/object/sign/profile-avatars/unit.jpg?token=short-lived"}',
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }
        if (r.url.path.contains('/storage/v1/object/')) {
          return http.Response(
            '{"Key":"profile-avatars/test.jpg","Id":"unit"}',
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '{}',
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await client.auth.signInWithPassword(
      email: 'unit@example.test',
      password: 'unit',
    );
    requests.clear();
    service = ProfileService(client);
  });
  tearDown(() async {
    await client.dispose();
  });

  test('remote photo URLs are restricted to HTTPS Google image hosts', () {
    expect(
      isGoogleAvatarUrl('https://lh3.googleusercontent.com/a/image'),
      isTrue,
    );
    for (final url in [
      'http://lh3.googleusercontent.com/a',
      'https://googleusercontent.com.evil.test/a',
      'https://evil.test/a',
      'https://user@lh3.googleusercontent.com/a',
      'https://lh3.googleusercontent.com:444/a',
    ]) {
      expect(isGoogleAvatarUrl(url), isFalse, reason: url);
    }
  });
  test(
    'removal commits null without upload, never consults Google metadata',
    () async {
      await service.updateAvatar(null);
      expect(requests.length, 1);
      expect(requests.single.url.path, endsWith('/rpc/update_my_avatar'));
      expect(jsonDecode(requests.single.body), {
        'p_path': null,
        'p_expected_actor': uid,
      });
    },
  );
  test('invalid and oversized image bytes never upload or commit', () async {
    for (final bytes in [
      Uint8List.fromList([1, 2, 3]),
      Uint8List(5 * 1024 * 1024 + 1),
    ]) {
      await expectLater(service.updateAvatar(bytes), throwsArgumentError);
    }
    expect(requests, isEmpty);
  });
  test('upload then commit uses versioned owned JPEG path', () async {
    final jpg = Uint8List.fromList(
      image.encodeJpg(image.Image(width: 32, height: 32)),
    );
    await service.updateAvatar(jpg);
    expect(requests.length, 2);
    expect(requests.first.url.path, contains('/object/profile-avatars/$uid/'));
    expect(
      requests.first.headers['content-type'],
      startsWith('multipart/form-data'),
    );
    expect(
      utf8.decode(requests.first.bodyBytes, allowMalformed: true),
      contains('image/jpeg'),
    );
    final path = (jsonDecode(requests.last.body) as Map)['p_path'] as String;
    expect(path, startsWith('$uid/'));
    expect(path, endsWith('.jpg'));
  });
  test(
    'ambiguous commit never deletes a potentially committed photo',
    () async {
      rejectCommit = true;
      final jpg = Uint8List.fromList(
        image.encodeJpg(image.Image(width: 32, height: 32)),
      );
      await expectLater(
        service.updateAvatar(jpg),
        throwsA(isA<PostgrestException>()),
      );
      expect(requests.where((r) => r.url.path.contains('/rpc/')).length, 1);
      expect(requests.where((r) => r.method == 'DELETE'), isEmpty);
    },
  );
  test('owned UUID object paths resolve a short-lived signed link', () async {
    final url = await service.resolveAvatarPath(
      '$uid/11111111-1111-4111-8111-111111111111.jpg',
    );
    expect(url, contains('token=short-lived'));
    expect(jsonDecode(requests.single.body), {'expiresIn': 60});
  });
  test('untrusted external URL never becomes a photo fetch', () async {
    expect(
      await service.resolveAvatarPath('https://evil.invalid/pixel'),
      isNull,
    );
    expect(requests, isEmpty);
  });
}
