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

Future<_ClaimResult> _attemptClaim(
  SupabaseClient client,
  String token,
  String learningLanguage,
) async {
  final userId = client.auth.currentUser!.id;
  try {
    final chatId = await ChatService(
      client,
    ).claimInvite(token: token, myLearningLanguage: learningLanguage);
    return _ClaimResult.success(userId, chatId);
  } catch (error) {
    return _ClaimResult.failure(userId, error);
  }
}

String? _postgrestMessage(Object? error) {
  return error is PostgrestException ? error.message : null;
}

void main() {
  test(
    'local Supabase preserves consent across signup, races, and expiry',
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

        final signupInvite = await ChatService(
          alice,
        ).createInvite(myLearningLanguage: 'de');
        tokens.add(signupInvite.token);
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
        expect(
          signup.session,
          isNotNull,
          reason: 'local email confirmation must remain disabled',
        );

        final signupChat = await ChatService(
          fresh,
        ).claimInvite(token: signupInvite.token, myLearningLanguage: 'fr');
        chatIds.add(signupChat);

        final signupMembers = List<Map<String, dynamic>>.from(
          await admin
              .from('chat_members')
              .select('user_id,learning_language')
              .eq('chat_id', signupChat),
        );
        expect(signupMembers, hasLength(2));
        expect(signupMembers.map((row) => row['user_id']).toSet(), {
          aliceId,
          freshUserId,
        });
        expect(
          signupMembers.singleWhere(
            (row) => row['user_id'] == freshUserId,
          )['learning_language'],
          'fr',
        );

        final freshChatList = await ChatService(fresh).fetchChatList();
        final claimedChat = freshChatList.singleWhere(
          (row) => row['chat_id'] == signupChat,
        );
        expect(claimedChat['partner_id'], aliceId);
        expect(claimedChat['my_learning'], 'fr');

        final raceInvite = await ChatService(
          alice,
        ).createInvite(myLearningLanguage: 'es');
        tokens.add(raceInvite.token);
        final race = await Future.wait([
          _attemptClaim(bob, raceInvite.token, 'de'),
          _attemptClaim(carol, raceInvite.token, 'it'),
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

        final expiredInvite = await ChatService(
          alice,
        ).createInvite(myLearningLanguage: 'de');
        tokens.add(expiredInvite.token);
        await admin
            .from('invites')
            .update({
              'expires_at': DateTime.now()
                  .subtract(const Duration(minutes: 1))
                  .toUtc()
                  .toIso8601String(),
            })
            .eq('token', expiredInvite.token);

        final expiredClaim = await _attemptClaim(
          bob,
          expiredInvite.token,
          'fr',
        );
        expect(expiredClaim.succeeded, isFalse);
        expect(_postgrestMessage(expiredClaim.error), 'invite_expired');

        final expiredMetadata = await ChatService(
          fresh,
        ).getInvite(expiredInvite.token);
        expect(expiredMetadata?.status, 'expired');
        final expiredRow = await admin
            .from('invites')
            .select('used_at,resulting_chat_id')
            .eq('token', expiredInvite.token)
            .single();
        expect(expiredRow['used_at'], isNull);
        expect(expiredRow['resulting_chat_id'], isNull);
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
