import 'dart:async';
import 'dart:convert';
import 'package:blab/shared/services/push_token_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'stream_chat_session_test.dart' show identify, createClient, alice, bob;

void main() {
  test(
    'device privacy is sent without caller-selected recipient or provider',
    () async {
      final requests = <Map<String, dynamic>>[];
      final client = createClient((r) async {
        expect(r.url.path, '/functions/v1/stream-device');
        requests.add(jsonDecode(r.body));
        return http.Response(
          '{"ok":true}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      addTearDown(client.dispose);
      await identify(client, alice);
      final repo = StreamPushTokenRepository(client);
      await repo.register(
        token: 'private-device-token',
        previewsEnabled: false,
      );
      await repo.unregister('private-device-token');
      expect(requests, [
        {
          'action': 'register',
          'token': 'private-device-token',
          'previewsEnabled': false,
        },
        {
          'action': 'unregister',
          'token': 'private-device-token',
          'previewsEnabled': false,
        },
      ]);
    },
  );
  test(
    'late registration acknowledgment cannot publish after identity changes',
    () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final client = createClient((r) {
        started.complete();
        return response.future;
      });
      addTearDown(client.dispose);
      await identify(client, alice);
      final pending = StreamPushTokenRepository(
        client,
      ).register(token: 'private-device-token', previewsEnabled: true);
      final rejection = expectLater(pending, throwsStateError);
      await started.future;
      await identify(client, bob);
      response.complete(
        http.Response(
          '{"ok":true}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await rejection;
    },
  );
  test('provider outage is not reported as accepted registration', () async {
    final client = createClient(
      (r) async => http.Response('{"error":"push_provider_unavailable"}', 503),
    );
    addTearDown(client.dispose);
    await identify(client, alice);
    await expectLater(
      StreamPushTokenRepository(
        client,
      ).register(token: 'private-device-token', previewsEnabled: true),
      throwsA(anything),
    );
  });
}
