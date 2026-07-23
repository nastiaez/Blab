import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/services/supabase_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _enabled = bool.fromEnvironment('RUN_LOCAL_SUPABASE_INTEGRATION');
const _url = String.fromEnvironment('SUPABASE_URL');
const _publicKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _serviceRoleKey = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');
const _password = 'Blab-local-123!';

SupabaseClient _client(String key) {
  return SupabaseClient(
    _url,
    key,
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
      authFlowType: AuthFlowType.implicit,
    ),
  );
}

Future<void> _signIn(SupabaseClient client, String email) async {
  await SupabaseAuthService(client).signIn(email: email, password: _password);
}

void main() {
  test(
    'push tokens stay private and message/invite events use the outbox',
    () async {
      expect(_url, isNotEmpty);
      expect(_publicKey, isNotEmpty);
      expect(_serviceRoleKey, isNotEmpty);

      final admin = _client(_serviceRoleKey);
      final alice = _client(_publicKey);
      final bob = _client(_publicKey);
      final clients = [admin, alice, bob];
      const aliceToken = 'alice-fcm-device-token-0001';
      const bobToken = 'bob-fcm-device-token-000001';
      String? chatId;

      try {
        await Future.wait([
          _signIn(alice, 'alice@blab.test'),
          _signIn(bob, 'bob@blab.test'),
        ]);
        final aliceId = alice.auth.currentUser!.id;
        final bobId = bob.auth.currentUser!.id;

        await alice.rpc(
          'register_push_token',
          params: {
            'p_token': aliceToken,
            'p_platform': 'android',
            'p_previews_enabled': true,
          },
        );
        await bob.rpc(
          'register_push_token',
          params: {
            'p_token': bobToken,
            'p_platform': 'android',
            'p_previews_enabled': false,
          },
        );

        await expectLater(
          alice.from('push_device_tokens').select('token,user_id'),
          throwsA(isA<PostgrestException>()),
        );
        final storedTokens = List<Map<String, dynamic>>.from(
          await admin
              .from('push_device_tokens')
              .select('token,user_id,previews_enabled')
              .inFilter('token', [aliceToken, bobToken]),
        );
        expect(storedTokens, hasLength(2));
        expect(
          storedTokens.singleWhere((row) => row['token'] == aliceToken),
          containsPair('user_id', aliceId),
        );
        expect(
          storedTokens.singleWhere((row) => row['token'] == bobToken),
          containsPair('previews_enabled', false),
        );

        // An account cannot unregister another account's device token.
        await alice.rpc('unregister_push_token', params: {'p_token': bobToken});
        expect(
          List<Map<String, dynamic>>.from(
            await admin
                .from('push_device_tokens')
                .select('token')
                .eq('token', bobToken),
          ),
          hasLength(1),
        );

        final invite = await ChatService(
          alice,
        ).createInvite(myLearningLanguage: 'de');
        chatId = await ChatService(
          bob,
        ).claimInvite(token: invite.token, myLearningLanguage: 'en');

        final inviteEvents = List<Map<String, dynamic>>.from(
          await admin
              .from('push_notification_events')
              .select('id,event_type,recipient_id,actor_id,chat_id,source_key')
              .eq('source_key', invite.token),
        );
        expect(inviteEvents, hasLength(1));
        expect(inviteEvents.single['event_type'], 'invite_claimed');
        expect(inviteEvents.single['recipient_id'], aliceId);
        expect(inviteEvents.single['actor_id'], bobId);

        final message = await ChatService(
          alice,
        ).sendMessage(chatId: chatId, body: 'Original notification preview');
        final messageEvents = List<Map<String, dynamic>>.from(
          await admin
              .from('push_notification_events')
              .select('id,event_type,recipient_id,actor_id,chat_id,source_key')
              .eq('source_key', message.id),
        );
        expect(messageEvents, hasLength(1));
        final event = messageEvents.single;
        expect(event['recipient_id'], bobId);
        expect(event['actor_id'], aliceId);
        expect(event.containsKey('body'), isFalse);

        final claimed = List<Map<String, dynamic>>.from(
          await admin.rpc(
            'claim_push_notification_event',
            params: {'p_event_id': event['id']},
          ),
        );
        expect(claimed, hasLength(1));
        expect(
          claimed.single['original_body'],
          'Original notification preview',
        );
        expect(claimed.single['interface_language'], 'en');
        expect(
          List<Map<String, dynamic>>.from(
            await admin.rpc(
              'claim_push_notification_event',
              params: {'p_event_id': event['id']},
            ),
          ),
          isEmpty,
        );

        const tokenHash =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        expect(
          await admin.rpc(
            'reserve_push_notification_delivery',
            params: {'p_event_id': event['id'], 'p_token_hash': tokenHash},
          ),
          isTrue,
        );
        expect(
          await admin.rpc(
            'reserve_push_notification_delivery',
            params: {'p_event_id': event['id'], 'p_token_hash': tokenHash},
          ),
          isFalse,
        );
      } finally {
        try {
          await alice.rpc(
            'unregister_push_token',
            params: {'p_token': aliceToken},
          );
          await bob.rpc('unregister_push_token', params: {'p_token': bobToken});
          if (chatId != null) {
            await admin.from('chats').delete().eq('id', chatId);
          }
        } catch (_) {
          // Preserve the original test failure.
        }
        for (final client in clients) {
          await client.dispose();
        }
      }
    },
    skip: !_enabled,
  );
}
