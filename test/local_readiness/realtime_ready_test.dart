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
  Duration timeout,
) async {
  while (await changes.moveNext().timeout(timeout)) {
    if (matches(changes.current)) return changes.current;
  }
  throw StateError('message_change_stream_closed');
}

Future<bool> _probeRealtime(
  SupabaseClient subscriber,
  SupabaseClient sender,
  String chatId,
  int attempt,
) async {
  final changes = StreamIterator(
    ChatService(subscriber).watchMessageChanges(chatId),
  );
  try {
    await _nextChange(
      changes,
      (change) => change.type == MessageChangeType.resync,
      const Duration(seconds: 10),
    );
    final probe = await ChatService(sender).sendMessage(
      chatId: chatId,
      body: 'local realtime readiness probe $attempt',
    );
    await _nextChange(
      changes,
      (change) =>
          change.type == MessageChangeType.upsert &&
          change.row?['id'] == probe.id,
      const Duration(seconds: 3),
    );
    return true;
  } on TimeoutException {
    return false;
  } finally {
    await changes.cancel();
  }
}

void main() {
  test(
    'local Realtime delivers a disposable Postgres change before integration',
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
        ).claimInvite(token: invite.token, myLearningLanguage: 'en');

        var ready = false;
        for (var attempt = 1; attempt <= 3 && !ready; attempt += 1) {
          ready = await _probeRealtime(alice, bob, chatId, attempt);
          if (!ready) {
            await Future<void>.delayed(const Duration(milliseconds: 250));
          }
        }
        expect(ready, isTrue, reason: 'local Realtime never delivered a probe');
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
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
