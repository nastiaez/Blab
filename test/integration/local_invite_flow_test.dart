import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/services/supabase_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _enabled = bool.fromEnvironment('RUN_LOCAL_SUPABASE_INTEGRATION');
const _url = String.fromEnvironment('SUPABASE_URL');
const _publicKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _serviceRoleKey = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');
const _password = 'Blab-local-123!';

class _ClaimResult {
  const _ClaimResult.success(this.userId, this.chatId) : error = null;
  const _ClaimResult.failure(this.userId, this.error) : chatId = null;

  final String userId;
  final String? chatId;
  final Object? error;

  bool get succeeded => chatId != null;
}

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

Future<_ClaimResult> _attemptClaim(SupabaseClient client, String token) async {
  final userId = client.auth.currentUser!.id;
  try {
    final result = await ChatService(client).claimInviteDetails(token: token);
    return _ClaimResult.success(userId, result.chatId);
  } catch (error) {
    return _ClaimResult.failure(userId, error);
  }
}

String? _postgrestMessage(Object? error) {
  return error is PostgrestException ? error.message : null;
}

void main() {
  test(
    'local Supabase keeps unclaimed invites valid and never resets a pair',
    () async {
      expect(_url, isNotEmpty);
      expect(_publicKey, isNotEmpty);
      expect(_serviceRoleKey, isNotEmpty);

      final admin = _client(_serviceRoleKey);
      final alice = _client(_publicKey);
      final bob = _client(_publicKey);
      final carol = _client(_publicKey);
      final fresh = _client(_publicKey);
      final clients = [admin, alice, bob, carol, fresh];
      final tokens = <String>[];
      final chatIds = <String>[];
      String? freshUserId;

      try {
        await Future.wait([
          _signIn(alice, 'alice@blab.test'),
          _signIn(bob, 'bob@blab.test'),
          _signIn(carol, 'carol@blab.test'),
        ]);
        final aliceId = alice.auth.currentUser!.id;

        final signupInvite = await ChatService(alice).createInvite();
        tokens.add(signupInvite.token);
        await admin
            .from('invites')
            .update({
              'created_at': DateTime.now()
                  .subtract(const Duration(hours: 49))
                  .toUtc()
                  .toIso8601String(),
            })
            .eq('token', signupInvite.token);
        final beforeSignup = await ChatService(
          fresh,
        ).getInvite(signupInvite.token);
        expect(beforeSignup?.status, 'valid');

        final unique = DateTime.now().microsecondsSinceEpoch;
        final signup = await SupabaseAuthService(fresh).signUp(
          name: 'L03 Integration',
          email: 'l03-$unique@blab.test',
          password: _password,
        );
        freshUserId = signup.user?.id;
        expect(freshUserId, isNotNull);
        final createdFreshUserId = freshUserId!;
        expect(
          signup.session,
          isNotNull,
          reason: 'local email confirmation must remain disabled',
        );

        final signupClaim = await ChatService(
          fresh,
        ).claimInviteDetails(token: signupInvite.token);
        final signupChat = signupClaim.chatId;
        chatIds.add(signupChat);
        expect(signupClaim.isNewConnection, isTrue);

        final signupMembers = List<Map<String, dynamic>>.from(
          await admin
              .from('chat_members')
              .select('user_id,learning_language,practice_language_selected_at')
              .eq('chat_id', signupChat),
        );
        expect(signupMembers, hasLength(2));
        expect(signupMembers.map((row) => row['user_id']).toSet(), {
          aliceId,
          createdFreshUserId,
        });
        expect(signupMembers.map((row) => row['learning_language']).toSet(), {
          'en',
        });
        expect(
          signupMembers
              .map((row) => row['practice_language_selected_at'])
              .toSet(),
          {null},
        );

        final freshChatList = await ChatService(fresh).fetchChatList();
        final claimedChat = freshChatList.singleWhere(
          (row) => row['chat_id'] == signupChat,
        );
        expect(claimedChat['partner_id'], aliceId);
        expect(claimedChat['needs_practice_language_selection'], isTrue);

        await ChatService(fresh).setLearningLanguage(
          chatId: signupChat,
          langCode: 'fr',
        );
        await ChatService(alice).setLearningLanguage(
          chatId: signupChat,
          langCode: 'de',
        );

        final repeatInvite = await ChatService(alice).createInvite();
        tokens.add(repeatInvite.token);
        final repeatClaim = await ChatService(
          fresh,
        ).claimInviteDetails(token: repeatInvite.token);
        expect(repeatClaim.chatId, signupChat);
        expect(repeatClaim.isNewConnection, isFalse);
        final repeatMembers = List<Map<String, dynamic>>.from(
          await admin
              .from('chat_members')
              .select('user_id,learning_language,practice_language_selected_at')
              .eq('chat_id', signupChat),
        );
        expect(
          repeatMembers.singleWhere(
            (row) => row['user_id'] == createdFreshUserId,
          )['learning_language'],
          'fr',
        );
        expect(
          repeatMembers.singleWhere(
            (row) => row['user_id'] == aliceId,
          )['learning_language'],
          'de',
        );

        final raceInvite = await ChatService(alice).createInvite();
        tokens.add(raceInvite.token);
        final race = await Future.wait([
          _attemptClaim(bob, raceInvite.token),
          _attemptClaim(carol, raceInvite.token),
        ]);
        final winner = race.singleWhere((result) => result.succeeded);
        final loser = race.singleWhere((result) => !result.succeeded);
        chatIds.add(winner.chatId!);
        expect(_postgrestMessage(loser.error), 'invite_already_claimed');

        final raceMetadata = await ChatService(
          fresh,
        ).getInvite(raceInvite.token);
        expect(raceMetadata?.status, 'used');
        expect(raceMetadata?.resultingChatId, winner.chatId);

        final raceMembers = List<Map<String, dynamic>>.from(
          await admin
              .from('chat_members')
              .select('user_id')
              .eq('chat_id', winner.chatId!),
        );
        final raceMemberIds = raceMembers
            .map((row) => row['user_id'] as String)
            .toSet();
        expect(raceMemberIds, {aliceId, winner.userId});
        expect(raceMemberIds, isNot(contains(loser.userId)));
      } finally {
        if (tokens.isNotEmpty) {
          await admin.from('invites').delete().inFilter('token', tokens);
        }
        if (chatIds.isNotEmpty) {
          await admin.from('chats').delete().inFilter('id', chatIds);
        }
        if (freshUserId != null) {
          await admin.auth.admin.deleteUser(freshUserId);
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
