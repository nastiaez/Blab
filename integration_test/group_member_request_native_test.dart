import 'package:blab/app/app_messenger.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:blab/features/chats/chats_screen.dart';
import 'package:blab/features/groups/group_info_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:blab/shared/state/privacy_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('private request preview, acceptance, block and fresh unblock', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (Uri.parse(url).host != '10.0.2.2') throw StateError('Local QA only');
    await Supabase.initialize(url: url, anonKey: key);
    final bob = Supabase.instance.client;
    final dana = SupabaseClient(url, key);
    final eve = SupabaseClient(url, key);
    addTearDown(dana.dispose);
    addTearDown(eve.dispose);
    for (final a in [
      (bob, 'bob@blab.test'),
      (dana, 'dana.groupqa@blab.test'),
      (eve, 'eve.groupqa@blab.test'),
    ]) {
      await a.$1.auth.signInWithPassword(
        email: a.$2,
        password: 'Blab-local-123!',
      );
    }
    final receiver = ChatService(bob);
    final sender = ChatService(dana);
    final other = ChatService(eve);
    final group = await sender.createGroup('Weekend');
    final invite = await sender.createGroupInvite(group);
    await receiver.joinGroup(invite.token);
    await other.joinGroup(invite.token);
    final request = await sender.contactGroupMember(
      group,
      bob.auth.currentUser!.id,
    );
    await sender.sendMessage(
      chatId: request,
      body: 'Hi Bob, shall we practise together?',
    );
    await expectLater(
      sender.sendMessage(
        chatId: request,
        body: 'Cannot send a second message yet',
      ),
      throwsA(isA<PostgrestException>()),
    );
    await receiver.setChatMode(chatId: request, mode: ChatMode.normal);
    final container = ProviderContainer(
      overrides: [
        isOnlineProvider.overrideWithValue(true),
        typingIndicatorsEnabledProvider.overrideWithValue(false),
        // Messaging/privacy proof only; live AI is a separate acceptance case.
        translateMessageFnProvider.overrideWithValue((id, {targetLang}) async {
          final row = await bob
              .from('messages')
              .select('body')
              .eq('id', id)
              .single();
          return MessageTranslation(
            translation: row['body'] as String,
            interfaceText: row['body'] as String,
            interfaceLang: 'en',
            sourceLang: 'en',
            tokens: const [],
            mode: LearningAidMode.none,
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    final groupChat = (await container.read(
      chatListProvider.future,
    )).singleWhere((c) => c.id == group);
    final router = GoRouter(
      initialLocation: '/chat/$request',
      routes: [
        GoRoute(
          path: '/chat/:id',
          builder: (_, s) => ChatScreen(chatId: s.pathParameters['id']!),
        ),
        GoRoute(path: '/chats', builder: (_, _) => const ChatsScreen()),
        GoRoute(
          path: '/group',
          builder: (_, _) => GroupInfoScreen(chat: groupChat),
        ),
      ],
    );
    addTearDown(router.dispose);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: blabTheme,
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: appMessengerKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    Future<void> until(Finder f) async {
      for (var i = 0; i < 150 && f.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(f, findsWidgets);
      await tester.pump(const Duration(milliseconds: 400));
    }

    await until(find.text('View message'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View message'));
    await until(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(
      (await dana.from('message_reads').select().eq('chat_id', request)),
      isEmpty,
    );
    await binding.takeScreenshot('01-private-request-preview');
    await tester.tap(find.text('Accept'));
    await until(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Yes, let’s practise!');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Send'));
    for (var i = 0; i < 100; i++) {
      if ((await sender.fetchMessages(
        request,
      )).any((m) => m.originalText == 'Yes, let’s practise!')) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      (await sender.fetchMessages(
        request,
      )).any((m) => m.originalText == 'Yes, let’s practise!'),
      isTrue,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02-private-request-accepted');
    final blockedRequest = await other.contactGroupMember(
      group,
      bob.auth.currentUser!.id,
    );
    await other.sendMessage(chatId: blockedRequest, body: 'Hello from Eve');
    await receiver.setLearningLanguage(chatId: blockedRequest, langCode: 'en');
    await receiver.setChatMode(chatId: blockedRequest, mode: ChatMode.normal);
    await container.read(chatListProvider.notifier).refresh();
    router.go('/chat/$blockedRequest');
    await until(find.text('Block'));
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Accept'), findsOneWidget);
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('03-block-private-request');
    await tester.tap(find.widgetWithText(TextButton, 'Block'));
    await until(find.byType(ChatsScreen));
    expect(
      (await other.fetchChatList()).any((c) => c['chat_id'] == blockedRequest),
      isFalse,
    );
    expect((await receiver.fetchGroupMembers(group)).length, 3);
    router.go('/group');
    await until(find.text('Eve Local'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eve Local').hitTestable());
    await until(find.text('Unblock and message'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('04-unblock-member-menu');
    await tester.tap(find.text('Unblock and message'));
    for (var i = 0; i < 150; i++) {
      if (router.routeInformationProvider.value.uri.path.startsWith('/chat/')) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    final fresh = router.routeInformationProvider.value.uri.path
        .split('/')
        .last;
    expect(fresh, isNot(blockedRequest));
    expect(await receiver.fetchMessages(fresh), isEmpty);
    await receiver.sendMessage(
      chatId: fresh,
      body: 'Fresh message after unblock',
    );
    expect(
      (await other.fetchMessages(fresh)).single.originalText,
      'Fresh message after unblock',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
