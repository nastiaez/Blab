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
    'sequential and concurrent re-invites converge on one pair chat',
    () async {
      expect(_url, isNotEmpty);
      expect(_publicKey, isNotEmpty);
      expect(_serviceRoleKey, isNotEmpty);

      final admin = _client(_serviceRoleKey);
      final alice = _client(_publicKey);
      final bob = _client(_publicKey);
      final clients = [admin, alice, bob];
      final tokens = <String>[];
      String? canonicalChatId;

      try {
        await Future.wait([
          _signIn(alice, 'alice@blab.test'),
          _signIn(bob, 'bob@blab.test'),
        ]);
        final aliceId = alice.auth.currentUser!.id;
        final bobId = bob.auth.currentUser!.id;
        final sortedIds = [aliceId, bobId]..sort();

        final firstInvite = await ChatService(alice).createInvite();
        tokens.add(firstInvite.token);
        canonicalChatId = await ChatService(
          bob,
        ).claimInvite(token: firstInvite.token);
        await ChatService(
          alice,
        ).setLearningLanguage(chatId: canonicalChatId, langCode: 'de');
        await ChatService(
          bob,
        ).setLearningLanguage(chatId: canonicalChatId, langCode: 'fr');

        final historyMessage = await ChatService(
          alice,
        ).sendMessage(chatId: canonicalChatId, body: 'preserved history');

        final secondInvite = await ChatService(alice).createInvite();
        tokens.add(secondInvite.token);
        final reusedChatId = await ChatService(
          bob,
        ).claimInvite(token: secondInvite.token);
        expect(reusedChatId, canonicalChatId);

        final members = List<Map<String, dynamic>>.from(
          await admin
              .from('chat_members')
              .select('user_id,learning_language,translation_cutoff_at')
              .eq('chat_id', canonicalChatId),
        );
        expect(
          members.singleWhere(
            (row) => row['user_id'] == aliceId,
          )['learning_language'],
          'de',
        );
        expect(
          members.singleWhere(
            (row) => row['user_id'] == bobId,
          )['learning_language'],
          'fr',
        );
        for (final member in members) {
          expect(member['translation_cutoff_at'], isNull);
        }

        await ChatService(
          bob,
        ).setLearningLanguage(chatId: canonicalChatId, langCode: 'fr');
        final unchangedCutoff = await admin
            .from('chat_members')
            .select('translation_cutoff_at')
            .eq('chat_id', canonicalChatId)
            .eq('user_id', bobId)
            .single();
        expect(unchangedCutoff['translation_cutoff_at'], isNull);

        await ChatService(
          bob,
        ).setLearningLanguage(chatId: canonicalChatId, langCode: 'de');
        final changedCutoff = await admin
            .from('chat_members')
            .select('translation_cutoff_at')
            .eq('chat_id', canonicalChatId)
            .eq('user_id', bobId)
            .single();
        expect(
          DateTime.parse(
            changedCutoff['translation_cutoff_at'] as String,
          ).isBefore(historyMessage.createdAt),
          isFalse,
        );

        await expectLater(
          bob
              .from('chat_members')
              .update({'translation_cutoff_at': null})
              .eq('chat_id', canonicalChatId)
              .eq('user_id', bobId),
          throwsA(isA<PostgrestException>()),
        );
        expect(
          (await ChatService(
            bob,
          ).fetchMessages(canonicalChatId)).single.originalText,
          'preserved history',
        );

        final reverseInvite = await ChatService(bob).createInvite();
        tokens.add(reverseInvite.token);
        final reverseChatId = await ChatService(
          alice,
        ).claimInvite(token: reverseInvite.token);
        expect(reverseChatId, canonicalChatId);
        final reverseMembers = List<Map<String, dynamic>>.from(
          await admin
              .from('chat_members')
              .select('user_id,learning_language')
              .eq('chat_id', canonicalChatId),
        );
        expect(
          reverseMembers.singleWhere(
            (row) => row['user_id'] == aliceId,
          )['learning_language'],
          'de',
        );
        expect(
          reverseMembers.singleWhere(
            (row) => row['user_id'] == bobId,
          )['learning_language'],
          'de',
        );

        final concurrentInvites = await Future.wait([
          ChatService(alice).createInvite(),
          ChatService(alice).createInvite(),
        ]);
        tokens.addAll(concurrentInvites.map((invite) => invite.token));
        final concurrentClaims = await Future.wait([
          ChatService(bob).claimInvite(token: concurrentInvites[0].token),
          ChatService(bob).claimInvite(token: concurrentInvites[1].token),
        ]);
        expect(concurrentClaims.toSet(), {canonicalChatId});

        final pairRows = List<Map<String, dynamic>>.from(
          await admin
              .from('chats')
              .select('id')
              .eq('member_low_id', sortedIds[0])
              .eq('member_high_id', sortedIds[1]),
        );
        expect(pairRows.single['id'], canonicalChatId);

        for (final invite in concurrentInvites) {
          final metadata = await ChatService(alice).getInvite(invite.token);
          expect(metadata?.status, 'used');
          expect(metadata?.resultingChatId, canonicalChatId);
        }
      } finally {
        if (tokens.isNotEmpty) {
          await admin.from('invites').delete().inFilter('token', tokens);
        }
        if (canonicalChatId != null) {
          await admin.from('chats').delete().eq('id', canonicalChatId);
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
