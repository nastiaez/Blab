import 'dart:async';

import 'package:blab/features/chat/state/typing_state.dart';
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

Future<RealtimeSubscribeStatus> _subscribe(RealtimeChannel channel) {
  final result = Completer<RealtimeSubscribeStatus>();
  channel.subscribe((status, _) {
    if (!result.isCompleted &&
        (status == RealtimeSubscribeStatus.subscribed ||
            status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut)) {
      result.complete(status);
    }
  });
  return result.future.timeout(const Duration(seconds: 15));
}

void main() {
  test(
    'private typing Broadcast allows members and rejects a non-member',
    () async {
      expect(_url, isNotEmpty);
      expect(_publicKey, isNotEmpty);
      expect(_serviceRoleKey, isNotEmpty);

      final admin = _client(_serviceRoleKey);
      final alice = _client(_publicKey);
      final bob = _client(_publicKey);
      final carol = _client(_publicKey);
      final clients = [admin, alice, bob, carol];
      RealtimeChannel? aliceChannel;
      RealtimeChannel? bobChannel;
      RealtimeChannel? carolChannel;
      SupabaseTypingTransport? aliceTransport;
      SupabaseTypingTransport? bobTransport;
      StreamSubscription<TypingEvent>? typingSubscription;
      TypingComposer? composer;
      String? inviteToken;
      String? chatId;

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
        final topic = typingTopic(chatId);
        const config = RealtimeChannelConfig(
          private: true,
          ack: true,
          self: false,
        );

        final received = Completer<Map<String, dynamic>>();
        bobChannel = bob
            .channel(topic, opts: config)
            .onBroadcast(
              event: typingBroadcastEvent,
              callback: (payload) {
                if (!received.isCompleted) received.complete(payload);
              },
            );
        aliceChannel = alice.channel(topic, opts: config);
        carolChannel = carol.channel(topic, opts: config);

        final memberStatuses = await Future.wait([
          _subscribe(bobChannel),
          _subscribe(aliceChannel),
        ]);
        expect(
          memberStatuses,
          everyElement(RealtimeSubscribeStatus.subscribed),
        );
        expect(
          await _subscribe(carolChannel),
          RealtimeSubscribeStatus.channelError,
        );

        final response = await aliceChannel.sendBroadcastMessage(
          event: typingBroadcastEvent,
          payload: {'user_id': alice.auth.currentUser!.id, 'is_typing': true},
        );
        expect(response, ChannelResponse.ok);

        final envelope = await received.future.timeout(
          const Duration(seconds: 10),
        );
        final nested = envelope['payload'];
        final payload = nested is Map
            ? Map<String, dynamic>.from(nested)
            : Map<String, dynamic>.from(envelope);
        expect(payload['user_id'], alice.auth.currentUser!.id);
        expect(payload['is_typing'], isTrue);

        await alice.removeChannel(aliceChannel);
        await bob.removeChannel(bobChannel);
        await carol.removeChannel(carolChannel);
        aliceChannel = null;
        bobChannel = null;
        carolChannel = null;

        aliceTransport = SupabaseTypingTransport(client: alice, chatId: chatId);
        bobTransport = SupabaseTypingTransport(client: bob, chatId: chatId);
        final productionEvents = <bool>[];
        typingSubscription = bobTransport.events.listen(
          (event) => productionEvents.add(event.isTyping),
        );
        await Future<void>.delayed(const Duration(seconds: 1));

        composer = TypingComposer(
          send: aliceTransport.send,
          isEnabled: () => true,
        );
        for (var i = 0; i < 8; i++) {
          composer.textChanged(true);
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        expect(productionEvents.where((value) => value).length, greaterThan(2));
        expect(productionEvents, isNot(contains(false)));

        await Future<void>.delayed(const Duration(milliseconds: 3200));
        expect(productionEvents.last, isFalse);

        composer.textChanged(true);
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(productionEvents.last, isTrue);
      } finally {
        composer?.dispose();
        await typingSubscription?.cancel();
        await aliceTransport?.close();
        await bobTransport?.close();
        if (aliceChannel != null) await alice.removeChannel(aliceChannel);
        if (bobChannel != null) await bob.removeChannel(bobChannel);
        if (carolChannel != null) await carol.removeChannel(carolChannel);
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
