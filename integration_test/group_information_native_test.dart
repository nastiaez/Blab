import 'dart:io';
import 'package:blab/app/theme.dart';
import 'package:blab/features/groups/group_info_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// The disposable groups backend intentionally excludes Realtime. All reads
// and mutations below still use its real authenticated REST/RPC endpoints.
class _LocalGroupService extends ChatService {
  _LocalGroupService(super.client);
  @override
  Stream<List<Map<String, dynamic>>> watchMyMemberships() =>
      const Stream.empty();
  @override
  Stream<void> watchChatListMessageChanges() => const Stream.empty();
  @override
  Stream<void> watchChatListTranslationChanges() => const Stream.empty();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('group information, rename and ownership on Android', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (!['10.0.2.2', '127.0.0.1'].contains(Uri.parse(url).host)) {
      throw StateError('Local QA only');
    }
    await Supabase.initialize(url: url, anonKey: key);
    final alice = Supabase.instance.client;
    final bob = SupabaseClient(url, key);
    final carol = SupabaseClient(url, key);
    addTearDown(bob.dispose);
    addTearDown(carol.dispose);
    for (final item in [(alice, 'alice'), (bob, 'bob'), (carol, 'carol')]) {
      await item.$1.auth.signInWithPassword(
        email: '${item.$2}@blab.test',
        password: 'Blab-local-123!',
      );
    }
    final owner = _LocalGroupService(alice);
    final id = await owner.createGroup('Weekend');
    final invite = await owner.createGroupInvite(id);
    await ChatService(bob).joinGroup(invite.token);
    await ChatService(carol).joinGroup(invite.token);
    final container = ProviderContainer(
      overrides: [chatServiceProvider.overrideWithValue(owner)],
    );
    addTearDown(container.dispose);
    final chats = await container.read(chatListProvider.future);
    final chat = chats.singleWhere((c) => c.id == id);
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: blabTheme,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(),
          initialRoute: '/group-review',
          routes: {'/group-review': (_) => GroupInfoScreen(chat: chat)},
        ),
      ),
    );
    Future<void> until(Finder f) async {
      for (var i = 0; i < 100 && f.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(f, findsWidgets);
    }

    await until(find.text('Alice Local (you)'));
    for (
      var i = 0;
      i < 100 && !container.read(groupPhotosProvider(id)).hasValue;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(container.read(groupPhotosProvider(id)).value, isEmpty);
    expect(find.text('No photos yet'), findsNothing);
    expect(find.text('SHARED MEDIA · 0'), findsNothing);
    expect(find.text('Bob Local'), findsOneWidget);
    expect(find.text('Carol Local'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await binding.takeScreenshot('01-group-information');
    final beforeNotice = await owner.fetchGroupMembers(id);
    final leave = find.byKey(const ValueKey('group-owner-leave'));
    await tester.ensureVisible(leave);
    await tester.tap(leave);
    await tester.pumpAndSettle();
    expect(find.text('Choose a new owner first'), findsOneWidget);
    await binding.takeScreenshot('04-owner-leave-notice');
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(await owner.fetchGroupMembers(id), beforeNotice);
    await binding.takeScreenshot('05-owner-notice-dismissed');
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Weekend plans');
    await tester.pump();
    await binding.takeScreenshot('02-edit-group-name');
    await tester.tap(find.text('Save'));
    await until(find.text('Weekend plans'));
    await tester.pumpAndSettle();
    expect(
      (await owner.fetchChatList()).singleWhere(
        (c) => c['chat_id'] == id,
      )['partner_name'],
      'Weekend plans',
    );
    await tester.tap(find.text('Bob Local'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('03-member-actions');
    await tester.tap(find.text('Make owner'));
    await tester.pumpAndSettle();
    await until(find.text('Weekend plans'));
    final members = await owner.fetchGroupMembers(id);
    expect(
      members.singleWhere((m) => m['is_owner'] == true)['user_id'],
      bob.auth.currentUser!.id,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
