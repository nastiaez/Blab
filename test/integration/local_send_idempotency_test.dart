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
  expect(client.auth.currentUser?.email, email);
}

void main() {
  test(
    'client message ids converge retries and reject conflicting reuse',
    () async {
      expect(_url, isNotEmpty);
      expect(_publicKey, isNotEmpty);
      expect(_serviceRoleKey, isNotEmpty);

      final admin = _client(_serviceRoleKey);
      final alice = _client(_publicKey);
      final bob = _client(_publicKey);
      final clients = [admin, alice, bob];
      const clientMessageId = '10000000-0000-4000-8000-000000000009';
      String? inviteToken;
      String? chatId;

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

        final first = await ChatService(alice).sendMessage(
          chatId: chatId,
          body: 'one logical send',
          clientMessageId: clientMessageId,
        );
        final retry = await ChatService(alice).sendMessage(
          chatId: chatId,
          body: 'one logical send',
          clientMessageId: clientMessageId,
        );
        expect(first.id, clientMessageId);
        expect(retry.id, first.id);
        expect(retry.createdAt, first.createdAt);
        expect(
          await admin
              .from('messages')
              .count(CountOption.exact)
              .eq('id', clientMessageId),
          1,
        );

        await expectLater(
          ChatService(alice).sendMessage(
            chatId: chatId,
            body: 'different payload',
            clientMessageId: clientMessageId,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'idempotency_conflict',
            ),
          ),
        );
        await expectLater(
          ChatService(bob).sendMessage(
            chatId: chatId,
            body: 'one logical send',
            clientMessageId: clientMessageId,
          ),
          throwsA(isA<StateError>()),
        );
      } finally {
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
}
