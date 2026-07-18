import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/services/supabase_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _enabled = bool.fromEnvironment('RUN_LOCAL_SUPABASE_INTEGRATION');
const _providerEnabled = bool.fromEnvironment(
  'RUN_LOCAL_OPENROUTER_INTEGRATION',
);
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
  expect(client.auth.currentUser?.email, email);
}

Map<String, dynamic> _map(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

void main() {
  test(
    'translation API enforces auth, membership, quota, and cache ownership',
    () async {
      expect(_url, isNotEmpty);
      expect(_publicKey, isNotEmpty);
      expect(_serviceRoleKey, isNotEmpty);

      final admin = _client(_serviceRoleKey);
      final anonymous = _client(_publicKey);
      final alice = _client(_publicKey);
      final bob = _client(_publicKey);
      final carol = _client(_publicKey);
      final clients = [admin, anonymous, alice, bob, carol];
      String? chatId;
      String? inviteToken;
      String? reportId;

      try {
        await Future.wait([
          _signIn(alice, 'alice@blab.test'),
          _signIn(bob, 'bob@blab.test'),
          _signIn(carol, 'carol@blab.test'),
        ]);

        final invite = await ChatService(
          alice,
        ).createInvite(myLearningLanguage: 'de');
        inviteToken = invite.token;
        chatId = await ChatService(
          bob,
        ).claimInvite(token: invite.token, myLearningLanguage: 'fr');
        final message = await ChatService(
          bob,
        ).sendMessage(chatId: chatId, body: 'Hello secure translation');

        await expectLater(
          anonymous.functions.invoke(
            'translate-message',
            body: {'messageId': message.id},
          ),
          throwsA(isA<FunctionException>()),
        );
        await expectLater(
          carol.functions.invoke(
            'translate-message',
            body: {'messageId': message.id},
          ),
          throwsA(
            isA<FunctionException>().having(
              (error) => error.status,
              'status',
              403,
            ),
          ),
        );

        final prepared = _map(
          await alice.rpc(
            'request_message_translation',
            params: {'p_message_id': message.id},
          ),
        );
        expect(prepared['status'], 'ready');
        expect(prepared['targetLang'], 'de');
        expect(prepared['text'], 'Hello secure translation');

        await expectLater(
          alice.from('message_translations').insert({
            'message_id': message.id,
            'target_lang': 'de',
            'translation_text': 'forged',
            'english_text': 'forged',
            'source_lang': 'en',
            'tokens': <Map<String, dynamic>>[],
            'source_hash': List.filled(64, '0').join(),
          }),
          throwsA(isA<PostgrestException>()),
        );

        expect(
          await admin.rpc(
            'complete_message_translation',
            params: {
              'p_message_id': message.id,
              'p_requester_id': alice.auth.currentUser!.id,
              'p_target_lang': prepared['targetLang'],
              'p_source_hash': prepared['sourceHash'],
              'p_translation_text': 'Hallo sichere Uebersetzung',
              'p_english_text': 'Hello secure translation',
              'p_source_lang': 'en',
              'p_tokens': [
                {
                  'text': 'Hallo sichere Uebersetzung',
                  'english': 'Hello secure translation',
                  'isContent': true,
                },
              ],
            },
          ),
          isTrue,
        );

        final response = await alice.functions.invoke(
          'translate-message',
          body: {'messageId': message.id},
        );
        final translated = _map(response.data);
        expect(response.status, 200);
        expect(translated['translation'], 'Hallo sichere Uebersetzung');
        expect(translated['english'], 'Hello secure translation');
        expect(
          (await admin
              .from('translation_usage')
              .select('minute_requests')
              .eq('user_id', alice.auth.currentUser!.id)
              .single())['minute_requests'],
          1,
        );

        final raceMessage = await ChatService(
          bob,
        ).sendMessage(chatId: chatId, body: 'Before edit');
        final racePrepared = _map(
          await alice.rpc(
            'request_message_translation',
            params: {'p_message_id': raceMessage.id},
          ),
        );
        await ChatService(
          bob,
        ).editMessage(messageId: raceMessage.id, newBody: 'After edit');
        expect(
          await admin.rpc(
            'complete_message_translation',
            params: {
              'p_message_id': raceMessage.id,
              'p_requester_id': alice.auth.currentUser!.id,
              'p_target_lang': racePrepared['targetLang'],
              'p_source_hash': racePrepared['sourceHash'],
              'p_translation_text': 'Vor Bearbeitung',
              'p_english_text': 'Before edit',
              'p_source_lang': 'en',
              'p_tokens': <Map<String, dynamic>>[],
            },
          ),
          isFalse,
        );

        reportId = await ChatService(alice).reportContent(
          reason: 'spam',
          reportedUserId: bob.auth.currentUser!.id,
          chatId: chatId,
        );
        await admin.rpc(
          'moderate_report',
          params: {
            'p_report_id': reportId,
            'p_action': 'suspend_account',
            'p_notes': 'L-13 local authorization test',
          },
        );
        final suspended = _map(
          await bob.rpc(
            'request_message_translation',
            params: {'p_message_id': message.id},
          ),
        );
        expect(suspended['status'], 'forbidden');
      } finally {
        if (reportId != null) {
          await admin
              .from('account_enforcements')
              .delete()
              .eq('user_id', bob.auth.currentUser?.id ?? '');
          await admin
              .from('moderation_actions')
              .delete()
              .eq('report_id', reportId);
          await admin.from('reports').delete().eq('id', reportId);
        }
        for (final user in [alice.auth.currentUser, bob.auth.currentUser]) {
          if (user != null) {
            await admin
                .from('translation_usage')
                .delete()
                .eq('user_id', user.id);
          }
        }
        if (inviteToken != null) {
          await admin.from('invites').delete().eq('token', inviteToken);
        }
        if (chatId != null) {
          await admin.from('chats').delete().eq('id', chatId);
        }
        await Future.wait(clients.map((client) => client.dispose()));
      }
    },
    skip: _enabled
        ? false
        : 'Run through scripts/local_test.sh integration against local Supabase.',
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'Azure ZDR route translates once and serves the next request from cache',
    () async {
      final admin = _client(_serviceRoleKey);
      final alice = _client(_publicKey);
      final bob = _client(_publicKey);
      final clients = [admin, alice, bob];
      String? chatId;
      String? inviteToken;

      try {
        await Future.wait([
          _signIn(alice, 'alice@blab.test'),
          _signIn(bob, 'bob@blab.test'),
        ]);
        final invite = await ChatService(
          alice,
        ).createInvite(myLearningLanguage: 'de');
        inviteToken = invite.token;
        chatId = await ChatService(
          bob,
        ).claimInvite(token: invite.token, myLearningLanguage: 'fr');
        final message = await ChatService(
          bob,
        ).sendMessage(chatId: chatId, body: 'Hello from the secure route');

        final first = _map(
          (await alice.functions.invoke(
            'translate-message',
            body: {'messageId': message.id},
          )).data,
        );
        expect(first['translation'], isA<String>());
        expect((first['translation'] as String).trim(), isNotEmpty);
        expect(first['english'], 'Hello from the secure route');
        expect(first['sourceLang'], 'en');

        final second = _map(
          (await alice.functions.invoke(
            'translate-message',
            body: {'messageId': message.id},
          )).data,
        );
        expect(second, first);
        expect(
          (await admin
              .from('translation_usage')
              .select('minute_requests')
              .eq('user_id', alice.auth.currentUser!.id)
              .single())['minute_requests'],
          1,
        );
      } finally {
        if (alice.auth.currentUser != null) {
          await admin
              .from('translation_usage')
              .delete()
              .eq('user_id', alice.auth.currentUser!.id);
        }
        if (inviteToken != null) {
          await admin.from('invites').delete().eq('token', inviteToken);
        }
        if (chatId != null) {
          await admin.from('chats').delete().eq('id', chatId);
        }
        await Future.wait(clients.map((client) => client.dispose()));
      }
    },
    skip: _enabled && _providerEnabled
        ? false
        : 'Requires local functions plus a development OpenRouter key.',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
