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

Matcher _postgrestMessage(String message) => isA<PostgrestException>().having(
  (error) => error.message,
  'message',
  message,
);

void main() {
  test(
    'reports are validated, private, actionable, enforced, and purged',
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
      String? reportId;
      late String bobId;

      try {
        await Future.wait([
          _signIn(alice, 'alice@blab.test'),
          _signIn(bob, 'bob@blab.test'),
          _signIn(carol, 'carol@blab.test'),
        ]);
        final aliceId = alice.auth.currentUser!.id;
        bobId = bob.auth.currentUser!.id;

        final invite = await ChatService(
          alice,
        ).createInvite(myLearningLanguage: 'de');
        inviteTokens.add(invite.token);
        final chatId = await ChatService(
          bob,
        ).claimInvite(token: invite.token, myLearningLanguage: 'fr');
        chatIds.add(chatId);

        final reportedMessage = await ChatService(
          bob,
        ).sendMessage(chatId: chatId, body: 'integration evidence');
        final aliceOwnedMessage = await ChatService(
          alice,
        ).sendMessage(chatId: chatId, body: 'not Bob evidence');

        await expectLater(
          alice.rpc(
            'submit_report',
            params: {
              'p_reason': 'harassment',
              'p_reported_user_id': bobId,
              'p_chat_id': chatId,
              'p_message_id': aliceOwnedMessage.id,
              'p_details': null,
            },
          ),
          throwsA(_postgrestMessage('reported_message_not_owned_by_user')),
        );

        reportId = await ChatService(alice).reportContent(
          reason: 'child_safety',
          reportedUserId: bobId,
          chatId: chatId,
          messageId: reportedMessage.id,
          details: 'Local integration report.',
        );
        expect(reportId, isNotEmpty);

        await expectLater(
          carol.rpc(
            'submit_report',
            params: {
              'p_reason': 'harassment',
              'p_reported_user_id': bobId,
              'p_chat_id': chatId,
              'p_message_id': reportedMessage.id,
              'p_details': null,
            },
          ),
          throwsA(_postgrestMessage('report_chat_forbidden')),
        );
        await expectLater(
          alice.from('reports').insert({
            'reporter_id': aliceId,
            'reported_user_id': bobId,
            'chat_id': chatId,
            'reason': 'other',
          }),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          alice.from('moderation_report_queue').select(),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          alice.rpc(
            'moderate_report',
            params: {
              'p_report_id': reportId,
              'p_action': 'dismiss',
              'p_notes': 'Unauthorized moderation attempt.',
            },
          ),
          throwsA(isA<PostgrestException>()),
        );

        final queued = Map<String, dynamic>.from(
          await admin
              .from('moderation_report_queue')
              .select()
              .eq('id', reportId)
              .single(),
        );
        expect(queued['status'], 'pending');
        expect(queued['priority'], 'child_safety');
        expect(queued['target_type'], 'message');
        expect(queued['reporter_id_snapshot'], aliceId);
        expect(queued['reported_user_id_snapshot'], bobId);
        expect(queued['message_body_snapshot'], 'integration evidence');

        await admin.rpc(
          'moderate_report',
          params: {
            'p_report_id': reportId,
            'p_action': 'start_review',
            'p_notes': null,
          },
        );
        await admin.rpc(
          'moderate_report',
          params: {
            'p_report_id': reportId,
            'p_action': 'suspend_account',
            'p_notes': 'Local integration suspension.',
          },
        );

        await expectLater(
          ChatService(bob).sendMessage(chatId: chatId, body: 'blocked send'),
          throwsA(isA<PostgrestException>()),
        );
        await ChatService(
          bob,
        ).editMessage(messageId: reportedMessage.id, newBody: 'blocked edit');
        final unchanged = (await ChatService(bob).fetchMessages(
          chatId,
        )).singleWhere((message) => message.id == reportedMessage.id);
        expect(unchanged.originalText, 'integration evidence');
        await expectLater(
          ChatService(bob).createInvite(myLearningLanguage: 'es'),
          throwsA(_postgrestMessage('account_suspended')),
        );

        final claimInvite = await ChatService(
          alice,
        ).createInvite(myLearningLanguage: 'it');
        inviteTokens.add(claimInvite.token);
        await expectLater(
          ChatService(
            bob,
          ).claimInvite(token: claimInvite.token, myLearningLanguage: 'de'),
          throwsA(_postgrestMessage('account_suspended')),
        );

        final aliceMessage = await ChatService(
          alice,
        ).sendMessage(chatId: chatId, body: 'active account still works');
        expect(aliceMessage.id, isNotEmpty);

        await admin.rpc(
          'moderate_report',
          params: {
            'p_report_id': reportId,
            'p_action': 'restore_account',
            'p_notes': 'Local integration restoration.',
          },
        );
        final restoredMessage = await ChatService(
          bob,
        ).sendMessage(chatId: chatId, body: 'restored send');
        expect(restoredMessage.id, isNotEmpty);
        final restoredInvite = await ChatService(
          bob,
        ).createInvite(myLearningLanguage: 'es');
        inviteTokens.add(restoredInvite.token);

        final actions = List<Map<String, dynamic>>.from(
          await admin
              .from('moderation_actions')
              .select('action,notes')
              .eq('report_id', reportId)
              .order('created_at'),
        );
        expect(actions.map((row) => row['action']).toSet(), {
          'start_review',
          'suspend_account',
          'restore_account',
        });

        await admin.rpc(
          'moderate_report',
          params: {
            'p_report_id': reportId,
            'p_action': 'dismiss',
            'p_notes': 'Close local integration report before purge.',
          },
        );
        await admin
            .from('reports')
            .update({
              'retention_until': DateTime.now()
                  .subtract(const Duration(minutes: 1))
                  .toUtc()
                  .toIso8601String(),
            })
            .eq('id', reportId);
        expect(await admin.rpc('purge_expired_moderation_evidence'), 1);

        final purged = await admin
            .from('reports')
            .select(
              'reporter_id_snapshot,reported_user_id_snapshot,'
              'message_body_snapshot,details,evidence_purged_at',
            )
            .eq('id', reportId)
            .single();
        expect(purged['reporter_id_snapshot'], isNull);
        expect(purged['reported_user_id_snapshot'], isNull);
        expect(purged['message_body_snapshot'], isNull);
        expect(purged['details'], isNull);
        expect(purged['evidence_purged_at'], isNotNull);

        final scrubbedActions = List<Map<String, dynamic>>.from(
          await admin
              .from('moderation_actions')
              .select('notes')
              .eq('report_id', reportId),
        );
        expect(scrubbedActions, isNotEmpty);
        expect(scrubbedActions, everyElement(containsPair('notes', null)));
      } finally {
        if (bob.auth.currentUser != null) {
          await admin
              .from('account_enforcements')
              .delete()
              .eq('user_id', bobId);
        }
        if (reportId != null) {
          await admin
              .from('moderation_actions')
              .delete()
              .eq('report_id', reportId);
          await admin.from('reports').delete().eq('id', reportId);
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

  test(
    'account deletion cascades live data but preserves minimized report evidence',
    () async {
      expect(_url, isNotEmpty);
      expect(_publicKey, isNotEmpty);
      expect(_serviceRoleKey, isNotEmpty);

      final admin = _client(_serviceRoleKey);
      final alice = _client(_publicKey);
      final disposable = _client(_publicKey);
      final clients = [admin, alice, disposable];
      String? disposableUserId;
      String? inviteToken;
      String? chatId;
      String? reportId;

      try {
        await _signIn(alice, 'alice@blab.test');
        final unique = DateTime.now().microsecondsSinceEpoch;
        final signup = await SupabaseAuthService(disposable).signUp(
          name: 'Disposable L07',
          email: 'l07-delete-$unique@blab.test',
          password: _password,
        );
        final targetUserId = signup.user!.id;
        disposableUserId = targetUserId;
        expect(signup.session, isNotNull);

        final invite = await ChatService(
          alice,
        ).createInvite(myLearningLanguage: 'de');
        inviteToken = invite.token;
        chatId = await ChatService(
          disposable,
        ).claimInvite(token: invite.token, myLearningLanguage: 'fr');
        final message = await ChatService(
          disposable,
        ).sendMessage(chatId: chatId, body: 'retained safety evidence');
        reportId = await ChatService(alice).reportContent(
          reason: 'harassment',
          reportedUserId: targetUserId,
          chatId: chatId,
          messageId: message.id,
        );

        await admin.auth.admin.deleteUser(targetUserId);

        final removedProfile = await alice
            .from('profiles')
            .select('id')
            .eq('id', targetUserId)
            .maybeSingle();
        expect(removedProfile, isNull);
        final removedMemberships = List<Map<String, dynamic>>.from(
          await admin
              .from('chat_members')
              .select('user_id')
              .eq('user_id', targetUserId),
        );
        expect(removedMemberships, isEmpty);
        expect(
          (await ChatService(
            alice,
          ).fetchMessages(chatId)).where((row) => row.id == message.id),
          isEmpty,
        );

        final retained = await admin
            .from('reports')
            .select(
              'reported_user_id,message_id,reported_user_id_snapshot,'
              'message_body_snapshot,retention_until',
            )
            .eq('id', reportId)
            .single();
        expect(retained['reported_user_id'], isNull);
        expect(retained['message_id'], isNull);
        expect(retained['reported_user_id_snapshot'], targetUserId);
        expect(retained['message_body_snapshot'], 'retained safety evidence');
        expect(retained['retention_until'], isNotNull);
      } finally {
        if (reportId != null) {
          await admin.from('reports').delete().eq('id', reportId);
        }
        if (inviteToken != null) {
          await admin.from('invites').delete().eq('token', inviteToken);
        }
        if (chatId != null) {
          await admin.from('chats').delete().eq('id', chatId);
        }
        if (disposableUserId != null) {
          try {
            await admin.auth.admin.deleteUser(disposableUserId);
          } catch (_) {
            // Already removed by the behavior under test.
          }
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
