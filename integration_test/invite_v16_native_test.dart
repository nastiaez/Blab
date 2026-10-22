import 'package:blab/features/groups/group_invite_screen.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'invite_v15_qa_app.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'V16 native contained search, navigation and private invitation',
    (tester) async {
      await app.main();
      Future<void> until(Finder finder) async {
        for (var i = 0; i < 180 && finder.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(finder, findsWidgets);
        await tester.pumpAndSettle();
      }

      Future<void> shot(String name) async {
        await tester.pump(const Duration(milliseconds: 700));
        if (name.contains('search') || name.contains('filtered')) {
          final external = find.byKey(const ValueKey('group-external-invite'));
          final body = find.byType(SingleChildScrollView);
          debugPrint('QA_LAYOUT|$name external=${tester.getRect(external)} body=${tester.getRect(body)}');
          expect(tester.getRect(external).top, greaterThanOrEqualTo(tester.getRect(body).top));
        }
        debugPrint('QA_SHOT|$name');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 3)),
        );
      }

      Future<void> hideKeyboard() async {
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await tester.pump(const Duration(milliseconds: 700));
      }

      await until(find.byType(FloatingActionButton));
      final service = ChatService(Supabase.instance.client);
      final contacts = await tester.runAsync(
        () => service.fetchGroupInviteFriends(app.qaGroupId),
      );
      final bob = contacts!.firstWhere((f) => f.name.startsWith('Bob'));
      final carol = contacts.firstWhere((f) => f.name.startsWith('Carol'));
      final bobRow = find.byKey(ValueKey('invite-friend-${bob.userId}'));
      final carolRow = find.byKey(ValueKey('invite-friend-${carol.userId}'));
      final search = find.byKey(const ValueKey('group-friend-search'));
      final openSearch = find.byKey(const ValueKey('group-open-search'));
      final send = find.byKey(const ValueKey('group-send-individual-invites'));
      app.qaRouter.push('/qa/group-details');
      await until(find.text('Invite friends'));
      await tester.ensureVisible(find.text('Invite friends'));
      await tester.tap(find.text('Invite friends'));
      await until(openSearch);
      expect(find.byType(GroupInviteScreen), findsOneWidget);
      await until(bobRow);
      expect(tester.widget<FilledButton>(send).onPressed, isNull);
      await shot('01-picker');
      await tester.tap(bobRow);
      await tester.tap(carolRow);
      await tester.pumpAndSettle();
      expect(find.text('Send invites (2)'), findsOneWidget);
      await shot('02-two-selected');
      await tester.tap(openSearch);
      await until(search);
      expect(tester.widget<TextField>(search).focusNode!.hasFocus, isTrue);
      await shot('03-search-keyboard');
      await hideKeyboard();
      await shot('04-search-contained');
      await tester.enterText(search, 'Car');
      await tester.pumpAndSettle();
      await hideKeyboard();
      expect(bobRow, findsNothing);
      expect(carolRow, findsOneWidget);
      expect(find.text('Send invites (2)'), findsOneWidget);
      await shot('05-filtered-selection');
      await tester.tap(find.byKey(const ValueKey('group-clear-search')));
      await tester.pumpAndSettle();
      expect(bobRow, findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(openSearch, findsOneWidget);
      expect(find.text('Send invites (2)'), findsOneWidget);
      await tester.tap(openSearch);
      await until(search);
      debugPrint('QA_SYSTEM_BACK|keyboard');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.pumpAndSettle();
      if (search.evaluate().isNotEmpty) {
        debugPrint('QA_SYSTEM_BACK|search');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 2)),
        );
        await tester.pumpAndSettle();
      }
      expect(openSearch, findsOneWidget);
      expect(find.text('Send invites (2)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('group-external-invite')));
      await until(find.text('Copy link'));
      await shot('06-external-link');
      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share link'));
      await tester.pump(const Duration(seconds: 1));
      await shot('09-native-share-sheet');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await until(openSearch);
      expect(find.text('Send invites (2)'), findsOneWidget);
      await tester.tap(carolRow);
      await tester.pumpAndSettle();
      expect(find.text('Send invite (1)'), findsOneWidget);
      await tester.tap(send);
      await until(find.text('Invitations sent.'));
      await shot('07-private-invitation-sent');
      await tester.runAsync(() async {
        const url = String.fromEnvironment('SUPABASE_URL');
        const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
        final b = SupabaseClient(url, key), c = SupabaseClient(url, key);
        try {
          await b.auth.signInWithPassword(
            email: 'bob@blab.test',
            password: 'Blab-local-123!',
          );
          await c.auth.signInWithPassword(
            email: 'carol@blab.test',
            password: 'Blab-local-123!',
          );
          final bInvites = await ChatService(b).fetchPendingGroupInvitations();
          final cInvites = await ChatService(c).fetchPendingGroupInvitations();
          expect(bInvites.any((i) => i.chatId == app.qaGroupId), isTrue);
          expect(cInvites.any((i) => i.chatId == app.qaGroupId), isFalse);
          expect(await service.fetchGroupMembers(app.qaGroupId), hasLength(1));
          debugPrint('QA_PRIVATE_INVITE|only-Bob; membership-unchanged');
        } finally {
          await b.dispose();
          await c.dispose();
        }
      });
    },
  );
}
