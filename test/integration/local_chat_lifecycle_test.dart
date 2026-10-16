import 'package:blab/shared/services/chat_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _enabled = bool.fromEnvironment('RUN_LOCAL_SUPABASE_INTEGRATION');
const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _adminKey = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');

SupabaseClient _client(String key) => SupabaseClient(
  _url,
  key,
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

void main() {
  test(
    'real clients preserve personal deletion, close both sides and reinvite fresh',
    () async {
      final admin = _client(_adminKey);
      final alice = _client(_key);
      final bob = _client(_key);
      final carol = _client(_key);
      final chats = <String>{};
      String? token;
      try {
        await Future.wait([
          for (final entry in [
            (alice, 'alice'),
            (bob, 'bob'),
            (carol, 'carol'),
          ])
            entry.$1.auth.signInWithPassword(
              email: '${entry.$2}@blab.test',
              password: 'Blab-local-123!',
            ),
        ]);
        final a = ChatService(alice);
        final b = ChatService(bob);
        token = (await a.createInvite()).token;
        final chat = await b.claimInvite(token: token);
        chats.add(chat);
        final oldMessage = await a.sendMessage(
          chatId: chat,
          body: 'Before personal deletion',
        );
        await b.deleteChat(chat);
        expect(
          (await b.fetchChatList()).where((row) => row['chat_id'] == chat),
          isEmpty,
        );
        expect(
          (await a.fetchChatList()).any((row) => row['chat_id'] == chat),
          isTrue,
        );
        expect((await b.fetchMessagePage(chat)).messages, isEmpty);
        expect(
          (await a.fetchMessagePage(
            chat,
          )).messages.any((m) => m.id == oldMessage.id),
          isTrue,
        );

        final incoming = await a.sendMessage(
          chatId: chat,
          body: 'A genuinely new incoming message',
        );
        expect(
          (await b.fetchChatList()).any((row) => row['chat_id'] == chat),
          isTrue,
        );
        expect((await b.fetchMessagePage(chat)).messages.map((m) => m.id), [
          incoming.id,
        ]);
        await expectLater(
          ChatService(carol).leaveChat(chat),
          throwsA(isA<PostgrestException>()),
        );
        await b.leaveChat(chat);
        await b.leaveChat(chat); // Lost-response retries are safe.
        for (final service in [a, b]) {
          final row = (await service.fetchChatList()).singleWhere(
            (row) => row['chat_id'] == chat,
          );
          expect(row['left_at'], isNotNull);
          expect(row['unread_count'], 0);
          await expectLater(
            service.sendMessage(chatId: chat, body: 'Stale client send'),
            throwsA(isA<PostgrestException>()),
          );
        }
        expect(
          (await a.fetchMessagePage(
            chat,
          )).messages.any((m) => m.id == oldMessage.id),
          isTrue,
        );
        final fresh = await b.claimInvite(token: token);
        chats.add(fresh);
        expect(fresh, isNot(chat));
        expect((await b.fetchMessagePage(fresh)).messages, isEmpty);
        expect(await b.claimInvite(token: token), fresh);
        final events = await admin
            .from('push_notification_events')
            .select('chat_id,source_key')
            .eq('event_type', 'invite_claimed')
            .eq('recipient_id', alice.auth.currentUser!.id)
            .eq('actor_id', bob.auth.currentUser!.id)
            .inFilter('chat_id', [chat, fresh]);
        expect(events, hasLength(2));
        expect(events.map((e) => e['chat_id']).toSet(), {chat, fresh});
        for (final event in events) {
          expect(
            event['source_key'],
            '$token:${bob.auth.currentUser!.id}:${event['chat_id']}',
          );
        }
      } finally {
        for (final chat in chats) {
          await admin.from('chats').delete().eq('id', chat);
        }
        if (token != null) {
          await admin.from('invites').delete().eq('token', token);
        }
        await Future.wait([
          admin.dispose(),
          alice.dispose(),
          bob.dispose(),
          carol.dispose(),
        ]);
      }
    },
    skip: _enabled
        ? false
        : 'Run with scripts/local_test.sh integration against disposable Supabase.',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
