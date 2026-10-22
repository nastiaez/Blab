import 'package:blab/features/groups/pending_group_invitations.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const enabled = bool.fromEnvironment('BLAB_INAPP_LOCAL_QA');
  test(
    'private live inbox updates on invitation, rejection and resend without reopening',
    () async {
      SharedPreferences.setMockInitialValues({});
      const url = 'http://127.0.0.1:59521';
      const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
      final alice = SupabaseClient(url, key), bob = SupabaseClient(url, key);
      final owner = ChatService(alice), recipient = ChatService(bob);
      await alice.auth.signInWithPassword(
        email: 'alice@blab.test',
        password: 'Blab-local-123!',
      );
      await bob.auth.signInWithPassword(
        email: 'bob@blab.test',
        password: 'Blab-local-123!',
      );
      final c = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(bob),
          currentUserIdProvider.overrideWithValue(bob.auth.currentUser!.id),
          chatServiceProvider.overrideWithValue(recipient),
        ],
      );
      final sub = c.listen(pendingGroupInvitationsProvider, (_, _) {});
      final id = await owner.createGroup('Live inbox proof');
      addTearDown(() async {
        sub.close();
        c.dispose();
        await bob.dispose();
        await owner.leaveGroup(id);
        await alice.dispose();
      });
      await c.read(pendingGroupInvitationsProvider.future);
      Future<void> waitFor(bool expected) async {
        for (var i = 0; i < 150; i++) {
          final has =
              c
                  .read(pendingGroupInvitationsProvider)
                  .value
                  ?.any((x) => x.chatId == id) ??
              false;
          if (has == expected) return;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        fail('Private live inbox did not reach expected presence=$expected');
      }

      await owner.sendGroupInvitations(id, [bob.auth.currentUser!.id]);
      await waitFor(true);
      final first = c
          .read(pendingGroupInvitationsProvider)
          .value!
          .singleWhere((x) => x.chatId == id);
      await recipient.rejectGroupInvitation(first.token);
      await waitFor(false);
      await owner.sendGroupInvitations(id, [bob.auth.currentUser!.id]);
      await waitFor(true);
      await recipient.rejectGroupInvitation(first.token);
      await waitFor(false);
    },
    skip: !enabled,
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
