import 'dart:convert';

import 'package:blab/shared/services/stream_backed_chat_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'stream_chat_session_test.dart' as fixtures;

void main() {
  test(
    'same signed-in client rechecks authority after activation and rollback',
    () async {
      var active = false;
      var calls = 0;
      final client = fixtures.createClient((request) async {
        expect(request.url.path, '/rest/v1/chat_message_transports');
        calls++;
        return http.Response(
          jsonEncode([
            {
              'provider': active ? 'stream' : 'supabase',
              'migration_state': active ? 'active' : 'rollback',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      await fixtures.identify(client, fixtures.alice);
      final service = StreamBackedChatService(client);
      expect(await service.usesStream('chat'), false);
      active = true;
      expect(await service.usesStream('chat'), true);
      active = false;
      expect(await service.usesStream('chat'), false);
      expect(calls, 3);
      await service.dispose();
      await client.dispose();
    },
  );
}
