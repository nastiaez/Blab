import 'package:blab/app/router.dart';
import 'package:blab/features/chats/chats_screen.dart';
import 'package:blab/features/groups/group_invite_screen.dart';
import 'package:blab/features/invite/invite_continuation.dart';
import 'package:blab/main.dart' as app;
import 'package:blab/shared/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native group link requires Join and uses the system share sheet',
    (tester) async {
      const url = String.fromEnvironment('SUPABASE_URL');
      const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
      if (Uri.parse(url).host != '10.0.2.2') throw StateError('Local QA only');
      await Supabase.initialize(url: url, anonKey: key);
      final alice = Supabase.instance.client;
      final bob = SupabaseClient(url, key);
      addTearDown(bob.dispose);
      for (final account in [(alice, 'alice'), (bob, 'bob')]) {
        await account.$1.auth.signInWithPassword(
          email: '${account.$2}@blab.test',
          password: 'Blab-local-123!',
        );
      }
      final owner = ChatService(bob);
      final id = await owner.createGroup('Trip plans');
      final groupName = 'Trip ${id.substring(0, 8)}';
      await owner.renameGroup(id, groupName);
      final invite = await owner.createGroupInvite(id);
      await owner.sendMessage(
        chatId: id,
        body: 'Earlier trip plans stay original.',
      );
      await clearPendingInvite();
      await binding.convertFlutterSurfaceToImage();
      blabRouter.go('/chats');
      await tester.pumpWidget(const ProviderScope(child: app.BlabApp()));
      Future<void> until(Finder finder) async {
        for (var i = 0; i < 300 && finder.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(finder, findsWidgets);
        await tester.pump(const Duration(milliseconds: 400));
      }

      await until(find.byType(ChatsScreen));
      debugPrint('GROUP_LINK_READY:${Uri.encodeComponent(invite.token)}');
      await until(find.text(groupName).hitTestable());
      await tester.tap(find.text(groupName).hitTestable());
      await until(find.text('Join').hitTestable());
      expect(find.text('Earlier trip plans stay original.'), findsNothing);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('01-native-invitation-before-join');
      await tester.tap(find.text('Join').hitTestable());
      await until(find.text('Choose a language to practice'));
      await tester.ensureVisible(find.text('German'));
      await until(find.text('German').hitTestable());
      await tester.tap(find.text('German').hitTestable());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Start practicing'));
      await until(find.text(groupName).hitTestable());
      await until(find.text('Earlier trip plans stay original.'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('02-native-link-joined-originals');
      await tester.tap(find.text(groupName).hitTestable());
      await until(find.text('Invite friends').hitTestable());
      await tester.tap(find.text('Invite friends').hitTestable());
      await until(find.text('Send invite').hitTestable());
      expect(find.byType(GroupInviteScreen), findsOneWidget);
      debugPrint('GROUP_SHARE_READY');
      await tester.tap(find.text('Send invite').hitTestable());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 8)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GroupInviteScreen), findsOneWidget);
      await binding.takeScreenshot('03-native-share-return-keeps-invite');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
