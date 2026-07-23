import 'dart:async';

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

Future<MessageChange> _nextChange(
  StreamIterator<MessageChange> changes,
  bool Function(MessageChange) matches,
  String stage,
) async {
  try {
    while (await changes.moveNext().timeout(const Duration(seconds: 10))) {
      if (matches(changes.current)) return changes.current;
    }
  } on TimeoutException {
    throw TimeoutException('Timed out waiting for $stage');
  }
  throw StateError('message_change_stream_closed');
}

void main() {
  test(
    'replies persist, stay in one chat, and edits invalidate translations',
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

      try {
        await Future.wait([
          _signIn(alice, 'alice@blab.test'),
          _signIn(bob, 'bob@blab.test'),
          _signIn(carol, 'carol@blab.test'),
        ]);

        final bobInvite = await ChatService(
          alice,
        ).createInvite(myLearningLanguage: 'de');
        inviteTokens.add(bobInvite.token);
        final aliceBobChat = await ChatService(
          bob,
        ).claimInvite(token: bobInvite.token, myLearningLanguage: 'fr');
        chatIds.add(aliceBobChat);

        final carolInvite = await ChatService(
          alice,
        ).createInvite(myLearningLanguage: 'de');
        inviteTokens.add(carolInvite.token);
        final aliceCarolChat = await ChatService(
          carol,
        ).claimInvite(token: carolInvite.token, myLearningLanguage: 'es');
        chatIds.add(aliceCarolChat);

        final realtimeService = ChatService(alice);
        final changes = StreamIterator(
          realtimeService.watchMessageChanges(aliceBobChat),
        );
        try {
          final subscribed = await _nextChange(
            changes,
            (change) => change.type == MessageChangeType.resync,
            'initial realtime subscription',
          );
          expect(subscribed.type, MessageChangeType.resync);

          final realtimeMessage = await ChatService(
            bob,
          ).sendMessage(chatId: aliceBobChat, body: 'realtime insert');
          final inserted = await _nextChange(
            changes,
            (change) =>
                change.type == MessageChangeType.upsert &&
                change.row?['id'] == realtimeMessage.id,
            'realtime insert',
          );
          expect(inserted.row?['body'], 'realtime insert');

          await ChatService(bob).editMessage(
            messageId: realtimeMessage.id,
            newBody: 'realtime edit',
          );
          final edited = await _nextChange(
            changes,
            (change) =>
                change.type == MessageChangeType.upsert &&
                change.row?['id'] == realtimeMessage.id &&
                change.row?['body'] == 'realtime edit',
            'realtime edit',
          );
          expect(edited.row?['body'], 'realtime edit');

          await ChatService(bob).softDelete(realtimeMessage.id);
          final removed = await _nextChange(
            changes,
            (change) =>
                change.type == MessageChangeType.remove &&
                change.row?['id'] == realtimeMessage.id,
            'realtime soft-delete',
          );
          expect(removed.type, MessageChangeType.remove);
        } finally {
          await changes.cancel();
        }

        final source = await ChatService(
          alice,
        ).sendMessage(chatId: aliceBobChat, body: 'reply source');
        const replyId = '10000000-0000-4000-8000-000000000010';
        await ChatService(bob).sendMessage(
          chatId: aliceBobChat,
          body: 'persisted reply',
          clientMessageId: replyId,
          replyToId: source.id,
        );

        final history = await ChatService(alice).fetchMessages(aliceBobChat);
        final reply = history.singleWhere((message) => message.id == replyId);
        expect(reply.replyTo?.id, source.id);
        expect(reply.replyTo?.originalText, 'reply source');
        final oneMessagePage = await ChatService(
          alice,
        ).fetchMessages(aliceBobChat, limit: 1);
        expect(oneMessagePage.single.id, replyId);
        expect(oneMessagePage.single.replyTo?.id, source.id);
        final newestPage = await ChatService(
          alice,
        ).fetchMessagePage(aliceBobChat, limit: 1);
        expect(newestPage.messages.single.id, replyId);
        expect(newestPage.hasMore, isTrue);
        expect(newestPage.nextCursor, isNotNull);
        final olderPage = await ChatService(alice).fetchMessagePage(
          aliceBobChat,
          limit: 1,
          before: newestPage.nextCursor,
        );
        expect(olderPage.messages.single.id, source.id);
        expect(olderPage.hasMore, isFalse);

        await ChatService(bob).sendMessage(
          chatId: aliceBobChat,
          body: 'persisted reply',
          clientMessageId: replyId,
          replyToId: source.id,
        );
        await expectLater(
          ChatService(bob).sendMessage(
            chatId: aliceBobChat,
            body: 'persisted reply',
            clientMessageId: replyId,
          ),
          throwsA(isA<StateError>()),
        );

        final otherChatSource = await ChatService(
          alice,
        ).sendMessage(chatId: aliceCarolChat, body: 'other chat');
        await expectLater(
          ChatService(bob).sendMessage(
            chatId: aliceBobChat,
            body: 'invalid cross-chat reply',
            replyToId: otherChatSource.id,
          ),
          throwsA(isA<PostgrestException>()),
        );

        const selfReplyId = '10000000-0000-4000-8000-000000000011';
        await expectLater(
          ChatService(bob).sendMessage(
            chatId: aliceBobChat,
            body: 'invalid self reply',
            clientMessageId: selfReplyId,
            replyToId: selfReplyId,
          ),
          throwsA(isA<PostgrestException>()),
        );

        final prepared = Map<String, dynamic>.from(
          await alice.rpc(
                'request_message_translation',
                params: {'p_message_id': source.id},
              )
              as Map,
        );
        expect(prepared['status'], 'ready');
        final completed = await admin.rpc(
          'complete_message_translation',
          params: {
            'p_message_id': source.id,
            'p_requester_id': alice.auth.currentUser!.id,
            'p_target_lang': prepared['targetLang'],
            'p_interface_lang': prepared['interfaceLang'],
            'p_source_hash': prepared['sourceHash'],
            'p_translation_text': 'alte Uebersetzung',
            'p_interface_text': 'reply source',
            'p_source_lang': 'en',
            'p_aid_mode': 'translation',
            'p_explanation': null,
            'p_confidence': null,
            'p_tokens': <Map<String, dynamic>>[],
          },
        );
        expect(completed, isTrue);
        final cached = await ChatService(alice).fetchCachedTranslation(
          messageId: source.id,
          targetLang: 'de',
          interfaceLang: 'en',
        );
        expect(cached?.text, 'alte Uebersetzung');
        expect(cached?.interfaceText, 'reply source');
        expect(cached?.interfaceLang, 'en');
        expect(cached?.sourceLang, 'en');
        expect(cached?.mode, 'translation');
        expect(
          await alice
              .from('message_translations')
              .count(CountOption.exact)
              .eq('message_id', source.id),
          1,
        );
        await ChatService(
          alice,
        ).editMessage(messageId: source.id, newBody: 'edited reply source');
        expect(
          await alice
              .from('message_translations')
              .count(CountOption.exact)
              .eq('message_id', source.id),
          0,
        );

        await ChatService(alice).softDelete(source.id);
        final afterDelete = await ChatService(bob).fetchMessages(aliceBobChat);
        final replyAfterDelete = afterDelete.singleWhere(
          (message) => message.id == replyId,
        );
        expect(replyAfterDelete.replyTo?.originalText, 'Deleted message');
      } finally {
        for (final token in inviteTokens) {
          await admin.from('invites').delete().eq('token', token);
        }
        for (final chatId in chatIds) {
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
