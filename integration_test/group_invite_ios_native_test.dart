import 'package:blab/shared/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'invite_v15_qa_app.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'iOS group invitation selection, search, link round-trip and privacy',
    (tester) async {
      await app.main();
      Future<void> until(Finder finder) async {
        for (var i = 0; i < 180 && finder.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(finder, findsWidgets);
        await tester.pumpAndSettle();
      }

      await until(find.byType(FloatingActionButton));
      app.qaRouter.push('/qa/group-details');
      await until(find.text('Invite friends'));
      await tester.ensureVisible(find.text('Invite friends'));
      await tester.tap(find.text('Invite friends'));
      final open = find.byKey(const ValueKey('group-open-search'));
      await until(open);
      final service = ChatService(Supabase.instance.client);
      final contacts = await tester.runAsync(
        () => service.fetchGroupInviteFriends(app.qaGroupId),
      );
      final bob = contacts!.firstWhere((f) => f.name.startsWith('Bob'));
      final carol = contacts.firstWhere((f) => f.name.startsWith('Carol'));
      final bobRow = find.byKey(ValueKey('invite-friend-${bob.userId}'));
      final carolRow = find.byKey(ValueKey('invite-friend-${carol.userId}'));
      await until(bobRow);
      await binding.takeScreenshot('01-ios-invite-picker');
      await tester.tap(bobRow);
      await tester.tap(carolRow);
      await tester.pumpAndSettle();
      expect(find.text('Send invites (2)'), findsOneWidget);
      await tester.tap(open);
      final search = find.byKey(const ValueKey('group-friend-search'));
      await until(search);
      await binding.takeScreenshot('02-ios-contained-search');
      await tester.enterText(search, 'Car');
      await tester.pumpAndSettle();
      expect(bobRow, findsNothing);
      expect(carolRow, findsOneWidget);
      expect(find.text('Send invites (2)'), findsOneWidget);
      await binding.takeScreenshot('03-ios-filtered-selection');
      await tester.tap(find.byKey(const ValueKey('group-clear-search')));
      await tester.pumpAndSettle();
      expect(bobRow, findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('group-external-invite')));
      await until(find.text('Copy link'));
      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();
      final copied = await Clipboard.getData('text/plain');
      expect(copied?.text, contains('https://'));
      await binding.takeScreenshot('04-ios-group-link');
      await tester.tap(find.byTooltip('Back'));
      await until(open);
      // The native Copy confirmation temporarily covers the pinned action.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Send invites (2)'), findsOneWidget);
      await tester.tap(carolRow);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('group-send-individual-invites')),
      );
      await until(find.text('Invitations sent.'));
      await tester.runAsync(() async {
        final other = SupabaseClient(
          const String.fromEnvironment('SUPABASE_URL'),
          const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
        );
        try {
          await other.auth.signInWithPassword(
            email: 'bob@blab.test',
            password: 'Blab-local-123!',
          );
          expect(
            (await ChatService(other).fetchPendingGroupInvitations()).any(
              (i) => i.chatId == app.qaGroupId,
            ),
            isTrue,
          );
          await other.auth.signInWithPassword(
            email: 'carol@blab.test',
            password: 'Blab-local-123!',
          );
          expect(
            (await ChatService(other).fetchPendingGroupInvitations()).any(
              (i) => i.chatId == app.qaGroupId,
            ),
            isFalse,
          );
          expect(await service.fetchGroupMembers(app.qaGroupId), hasLength(1));
        } finally {
          await other.dispose();
        }
      });
    },
  );
}
