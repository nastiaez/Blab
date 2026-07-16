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
    'profile, message update, and read receipt boundaries are enforced',
    () async {
      expect(_url, isNotEmpty);
      expect(_publicKey, isNotEmpty);
      expect(_serviceRoleKey, isNotEmpty);

      final admin = _client(_serviceRoleKey);
      final alice = _client(_publicKey);
      final bob = _client(_publicKey);
      final carol = _client(_publicKey);
      final clients = [admin, alice, bob, carol];
      final chatIds = <String>[];
      final inviteTokens = <String>[];
      late String aliceId;
      late String bobId;
      late String carolId;
      String? originalAliceName;

      try {
        await Future.wait([
          _signIn(alice, 'alice@blab.test'),
          _signIn(bob, 'bob@blab.test'),
          _signIn(carol, 'carol@blab.test'),
        ]);
        aliceId = alice.auth.currentUser!.id;
        bobId = bob.auth.currentUser!.id;
        carolId = carol.auth.currentUser!.id;

        final aliceInvite = await ChatService(
          alice,
        ).createInvite(myLearningLanguage: 'de');
        inviteTokens.add(aliceInvite.token);
        final aliceBobChat = await ChatService(
          bob,
        ).claimInvite(token: aliceInvite.token, myLearningLanguage: 'fr');
        chatIds.add(aliceBobChat);

        final ownProfile = await alice
            .from('profiles')
            .select('id,display_name')
            .eq('id', aliceId)
            .single();
        originalAliceName = ownProfile['display_name'] as String;
        expect(originalAliceName, isNotEmpty);
        final partnerProfile = await alice
            .from('profiles')
            .select('id,display_name')
            .eq('id', bobId)
            .single();
        expect(partnerProfile['display_name'], 'Bob Local');
        final unrelatedProfiles = List<Map<String, dynamic>>.from(
          await alice.from('profiles').select('id').eq('id', carolId),
        );
        expect(unrelatedProfiles, isEmpty);

        await alice
            .from('profiles')
            .update({'display_name': 'Alice L08'})
            .eq('id', aliceId);
        expect(
          (await bob
              .from('profiles')
              .select('display_name')
              .eq('id', aliceId)
              .single())['display_name'],
          'Alice L08',
        );
        await expectLater(
          alice
              .from('profiles')
              .update({'created_at': DateTime.utc(2000).toIso8601String()})
              .eq('id', aliceId),
          throwsA(isA<PostgrestException>()),
        );

        final freshMessage = await ChatService(
          alice,
        ).sendMessage(chatId: aliceBobChat, body: 'fresh body');
        await ChatService(
          alice,
        ).editMessage(messageId: freshMessage.id, newBody: 'edited body');
        final edited = await admin
            .from('messages')
            .select('body,edited_at')
            .eq('id', freshMessage.id)
            .single();
        expect(edited['body'], 'edited body');
        expect(edited['edited_at'], isNotNull);

        await ChatService(
          bob,
        ).editMessage(messageId: freshMessage.id, newBody: 'forged body');
        expect(
          (await admin
              .from('messages')
              .select('body')
              .eq('id', freshMessage.id)
              .single())['body'],
          'edited body',
        );
        await expectLater(
          alice
              .from('messages')
              .update({'sender_id': bobId})
              .eq('id', freshMessage.id),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          alice.from('messages').delete().eq('id', freshMessage.id),
          throwsA(isA<PostgrestException>()),
        );

        final oldMessage = await ChatService(
          alice,
        ).sendMessage(chatId: aliceBobChat, body: 'old body');
        await admin
            .from('messages')
            .update({
              'created_at': DateTime.now()
                  .subtract(const Duration(hours: 25))
                  .toUtc()
                  .toIso8601String(),
            })
            .eq('id', oldMessage.id);
        await expectLater(
          ChatService(
            alice,
          ).editMessage(messageId: oldMessage.id, newBody: 'too late'),
          throwsA(
            isA<PostgrestException>().having(
              (error) => error.message,
              'message',
              'message_edit_window_expired',
            ),
          ),
        );
        await ChatService(alice).softDelete(oldMessage.id);
        expect(
          (await admin
              .from('messages')
              .select('deleted_at')
              .eq('id', oldMessage.id)
              .single())['deleted_at'],
          isNotNull,
        );
        await expectLater(
          ChatService(
            alice,
          ).editMessage(messageId: oldMessage.id, newBody: 'deleted edit'),
          throwsA(isA<PostgrestException>()),
        );
        await ChatService(alice).restoreMessage(oldMessage.id);
        expect(
          (await admin
              .from('messages')
              .select('deleted_at')
              .eq('id', oldMessage.id)
              .single())['deleted_at'],
          isNull,
        );

        final bobMessage = await ChatService(
          bob,
        ).sendMessage(chatId: aliceBobChat, body: 'Bob incoming');
        await ChatService(
          bob,
        ).markRead(chatId: aliceBobChat, messageIds: [freshMessage.id]);
        await ChatService(
          bob,
        ).markRead(chatId: aliceBobChat, messageIds: [freshMessage.id]);
        expect(
          await admin
              .from('message_reads')
              .count(CountOption.exact)
              .eq('message_id', freshMessage.id)
              .eq('user_id', bobId),
          1,
        );
        await expectLater(
          ChatService(
            bob,
          ).markRead(chatId: aliceBobChat, messageIds: [bobMessage.id]),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          ChatService(
            carol,
          ).markRead(chatId: aliceBobChat, messageIds: [freshMessage.id]),
          throwsA(isA<PostgrestException>()),
        );

        final carolInvite = await ChatService(
          carol,
        ).createInvite(myLearningLanguage: 'es');
        inviteTokens.add(carolInvite.token);
        final bobCarolChat = await ChatService(
          bob,
        ).claimInvite(token: carolInvite.token, myLearningLanguage: 'it');
        chatIds.add(bobCarolChat);
        await expectLater(
          ChatService(
            bob,
          ).markRead(chatId: bobCarolChat, messageIds: [freshMessage.id]),
          throwsA(isA<PostgrestException>()),
        );

        final chatList = List<Map<String, dynamic>>.from(
          await alice.from('chat_list').select('partner_id,partner_name'),
        );
        expect(chatList, hasLength(1));
        expect(chatList.single['partner_id'], bobId);
        expect(chatList.single['partner_name'], 'Bob Local');
      } finally {
        if (alice.auth.currentUser != null && originalAliceName != null) {
          await alice
              .from('profiles')
              .update({'display_name': originalAliceName})
              .eq('id', alice.auth.currentUser!.id);
        }
        if (inviteTokens.isNotEmpty) {
          await admin.from('invites').delete().inFilter('token', inviteTokens);
        }
        if (chatIds.isNotEmpty) {
          await admin.from('chats').delete().inFilter('id', chatIds);
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
