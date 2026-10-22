import 'dart:io';
import 'package:blab/app/telegram_route.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chats/chats_screen.dart';
import 'package:blab/features/groups/group_info_screen.dart';
import 'package:blab/features/groups/group_invite_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real Android group leave, rejoin, removal and last-member closure',
    (tester) async {
      const url = String.fromEnvironment('SUPABASE_URL');
      const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
      if (!['10.0.2.2', '127.0.0.1'].contains(Uri.parse(url).host)) {
        throw StateError('Local QA only');
      }
      await Supabase.initialize(url: url, anonKey: key);
      final alice = Supabase.instance.client;
      final bob = SupabaseClient(url, key);
      addTearDown(bob.dispose);
      for (final item in [(alice, 'alice'), (bob, 'bob')]) {
        await item.$1.auth.signInWithPassword(
          email: '${item.$2}@blab.test',
          password: 'Blab-local-123!',
        );
      }
      final service = ChatService(alice);
      final owner = ChatService(bob);
      final id = await owner.createGroup('Weekend');
      final invite = await owner.createGroupInvite(id);
      await bob.from('messages').insert({
        'chat_id': id,
        'sender_id': bob.auth.currentUser!.id,
        'body': 'Before Alice joined.',
      });
      await service.joinGroup(invite.token);
      await alice.rpc(
        'set_learning_language',
        params: {'p_chat_id': id, 'p_learning_language': 'de'},
      );
      final container = ProviderContainer(
        overrides: [chatServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/chat/$id',
        routes: [
          GoRoute(
            path: '/chats',
            pageBuilder: (_, s) =>
                NoTransitionPage(key: s.pageKey, child: const ChatsScreen()),
          ),
          GoRoute(
            path: '/chat/:id',
            pageBuilder: (_, s) => TelegramPage(
              key: s.pageKey,
              child: ChatScreen(chatId: s.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/group/:id/invite',
            pageBuilder: (_, s) => TelegramPage(
              key: s.pageKey,
              child: GroupInviteScreen(
                chatId: s.pathParameters['id']!,
                initialToken: null,
              ),
            ),
          ),
          GoRoute(
            path: '/group-invite/:token',
            pageBuilder: (_, s) => TelegramPage(
              key: s.pageKey,
              child: GroupJoinScreen(token: s.pathParameters['token']!),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            theme: blabTheme,
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      Future<void> until(Finder f) async {
        for (var i = 0; i < 160 && f.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(f, findsWidgets);
        await tester.pump(const Duration(milliseconds: 400));
      }

      Future<void> info() async {
        await until(find.text('Weekend').hitTestable());
        await tester.tap(find.text('Weekend').hitTestable().first);
        await until(find.byType(GroupInfoScreen));
        await until(find.text('Bob Local'));
      }

      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        await binding.takeScreenshot(name);
      }

      await until(find.textContaining('Before Alice joined.'));
      await capture('01-native-original-history');
      await info();
      await tester.ensureVisible(find.byKey(const ValueKey('group-delete')));
      await tester.tap(find.byKey(const ValueKey('group-delete')));
      await until(find.text('Delete group?'));
      await capture('00-native-personal-delete-confirmation');
      await tester.tap(find.widgetWithText(TextButton, 'Delete group'));
      await until(find.byType(ChatsScreen));
      expect(await service.fetchMessages(id), isEmpty);
      expect(
        (await owner.fetchMessages(
          id,
        )).any((message) => message.originalText == 'Before Alice joined.'),
        isTrue,
      );
      expect((await owner.fetchGroupMembers(id)).length, 2);
      await service.setChatMode(chatId: id, mode: ChatMode.normal);
      await owner.sendMessage(
        chatId: id,
        body: 'A new message brings this group back.',
      );
      expect(
        (await service.fetchChatList()).any((row) => row['chat_id'] == id),
        isTrue,
      );
      expect(
        (await service.fetchMessages(
          id,
        )).any((message) => message.originalText == 'Before Alice joined.'),
        isFalse,
      );
      router.go('/chat/$id');
      await until(find.text('A new message brings this group back.'));
      await info();
      await tester.ensureVisible(
        find.byKey(const ValueKey('group-owner-leave')),
      );
      await tester.tap(find.byKey(const ValueKey('group-owner-leave')));
      await until(find.text('Leave group?'));
      await capture('02-native-leave-confirmation');
      await tester.tap(find.widgetWithText(TextButton, 'Leave group'));
      await until(find.byType(ChatsScreen));
      expect(
        await alice.from('messages').select('id').eq('chat_id', id),
        isEmpty,
      );
      expect(
        (await service.fetchChatList()).where((r) => r['chat_id'] == id),
        isEmpty,
      );

      router.go('/group-invite/${Uri.encodeComponent(invite.token)}');
      await until(find.text('Join'));
      await tester.tap(find.text('Join'));
      await until(find.text('Choose a language to practice'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('German'));
      await until(find.text('German').hitTestable());
      await tester.tap(find.text('German').hitTestable());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Start practicing'));
      for (
        var i = 0;
        i < 100 &&
            find.text('Choose a language to practice').evaluate().isNotEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Choose a language to practice'), findsNothing);
      await until(find.textContaining('Before Alice joined.'));
      await capture('03-native-rejoined-original-history');
      expect(
        await alice
            .from('message_prepared_packages')
            .select('message_id')
            .eq('chat_id', id),
        isEmpty,
      );

      // Real backend ownership change must reach the open screen, without a mock feed.
      await info();
      await owner.transferGroupOwner(id, alice.auth.currentUser!.id);
      for (
        var i = 0;
        i < 100 &&
            container
                    .read(chatListProvider)
                    .asData
                    ?.value
                    .where((c) => c.id == id)
                    .firstOrNull
                    ?.ownerId !=
                alice.auth.currentUser!.id;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Bob Local'));
      await until(find.text('Remove from group'));
      await tester.tap(find.text('Remove from group'));
      await until(find.text('Remove member?'));
      await capture('04-native-remove-member');
      await tester.tap(find.widgetWithText(TextButton, 'Remove from group'));
      for (
        var i = 0;
        i < 100 && find.text('Remove member?').evaluate().isNotEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        await bob.from('messages').select('id').eq('chat_id', id),
        isEmpty,
      );
      try {
        await owner.joinGroup(invite.token);
        fail('removed member reused an old invite');
      } on PostgrestException catch (e) {
        expect(e.message, contains('fresh_group_invitation_required'));
      }

      await container.read(chatListProvider.notifier).refresh();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.ensureVisible(
        find.byKey(const ValueKey('group-owner-leave')),
      );
      await tester.tap(find.byKey(const ValueKey('group-owner-leave')));
      await until(find.text('Close group?'));
      await capture('05-native-close-last-member');
      await tester.tap(find.widgetWithText(TextButton, 'Close group'));
      await until(find.byType(ChatsScreen));
      expect((await owner.getGroupInvite(invite.token))!.status, 'unavailable');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
