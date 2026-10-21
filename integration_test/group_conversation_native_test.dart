import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:blab/features/chats/chats_screen.dart';
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
  testWidgets('three-account group text journey on local backend', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (Uri.parse(url).host != '10.0.2.2') throw StateError('Local QA only');
    await Supabase.initialize(url: url, anonKey: key);
    final bob = Supabase.instance.client;
    final alice = SupabaseClient(url, key);
    final carol = SupabaseClient(url, key);
    addTearDown(alice.dispose);
    addTearDown(carol.dispose);
    for (final account in [(bob, 'bob'), (alice, 'alice'), (carol, 'carol')]) {
      await account.$1.auth.signInWithPassword(
        email: '${account.$2}@blab.test',
        password: 'Blab-local-123!',
      );
    }
    final owner = ChatService(alice);
    final recipient = ChatService(bob);
    final third = ChatService(carol);
    final chatId = await owner.createGroup('Weekend');
    final token = await owner.createGroupInvite(chatId);
    await owner.setLearningLanguage(chatId: chatId, langCode: 'en');
    await owner.sendMessage(
      chatId: chatId,
      body: 'Original message before joining',
    );
    await recipient.joinGroup(token.token);
    await third.joinGroup(token.token);
    await recipient.setLearningLanguage(chatId: chatId, langCode: 'en');
    await third.setLearningLanguage(chatId: chatId, langCode: 'de');
    await recipient.setChatMode(chatId: chatId, mode: ChatMode.normal);
    await owner.sendMessage(chatId: chatId, body: 'Coffee tomorrow?');
    await third.sendMessage(chatId: chatId, body: 'Yes, at ten!');
    expect(
      (await recipient.fetchMessages(
        chatId,
      )).any((m) => m.originalText == 'Original message before joining'),
      true,
    );

    final router = GoRouter(
      initialLocation: '/chat/$chatId',
      routes: [
        GoRoute(
          path: '/chat/:id',
          builder: (_, state) =>
              ChatScreen(chatId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/chats', builder: (_, _) => const ChatsScreen()),
      ],
    );
    addTearDown(router.dispose);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          typingIndicatorsEnabledProvider.overrideWithValue(false),
          // Isolate messaging/layout from paid AI generation. No provider calls.
          translateMessageFnProvider.overrideWithValue((
            id, {
            targetLang,
          }) async {
            final row = await bob
                .from('messages')
                .select('body')
                .eq('id', id)
                .single();
            final text = row['body'] as String;
            return MessageTranslation(
              translation: text,
              interfaceText: text,
              interfaceLang: 'en',
              sourceLang: 'en',
              tokens: const [],
              mode: LearningAidMode.none,
            );
          }),
        ],
        child: MaterialApp.router(
          theme: blabTheme,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    Future<void> settleUntil(Finder finder) async {
      for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(finder, findsWidgets);
    }

    await settleUntil(find.text('Coffee tomorrow?'));
    await settleUntil(find.text('Yes, at ten!'));
    expect(find.text('Original message before joining'), findsOneWidget);
    expect(find.text('3 members'), findsOneWidget);
    expect(find.text('Alice Local'), findsWidgets);
    expect(find.text('Carol Local'), findsWidgets);
    await tester.pump(const Duration(seconds: 2));
    await binding.takeScreenshot('01-group-conversation');
    await tester.enterText(
      find.byKey(const ValueKey('composer-message-text-field')),
      'See you there!',
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byTooltip('Send'));
    FocusManager.instance.primaryFocus?.unfocus();
    await settleUntil(find.text('See you there!'));
    await tester.pump(const Duration(seconds: 2));
    expect(
      (await owner.fetchMessages(
        chatId,
      )).any((m) => m.originalText == 'See you there!'),
      true,
    );
    expect(
      (await third.fetchMessages(
        chatId,
      )).any((m) => m.originalText == 'See you there!'),
      true,
    );
    await binding.takeScreenshot('02-group-reply');
    // Real Android MediaStore picker, not an overridden image-picker service.
    // Fixture image and photo permission are prepared on the disposable AVD.
    await tester.tap(find.byTooltip('Attach'));
    await settleUntil(find.byKey(const ValueKey('gallery-picker-grid')));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('04-native-photo-picker');
    await tester.tap(find.byKey(const ValueKey('gallery-picker-close')));
    await tester.pumpAndSettle();
    expect(await recipient.fetchGroupPhotos(chatId), isEmpty);
    await tester.tap(find.byTooltip('Attach'));
    final tile = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('gallery-tile-'),
    );
    await settleUntil(tile);
    await tester.tap(tile.first);
    await settleUntil(find.byKey(const ValueKey('photo-preview-fullscreen')));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('05-native-photo-preview');
    await tester.tap(find.byKey(const ValueKey('photo-preview-close')));
    await tester.pumpAndSettle();
    expect(await recipient.fetchGroupPhotos(chatId), isEmpty);
    await tester.tap(find.byTooltip('Attach'));
    await settleUntil(tile);
    await tester.tap(tile.first);
    await settleUntil(find.byKey(const ValueKey('photo-preview-send')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('photo-preview-send')));
    for (var i = 0; i < 100; i++) {
      if ((await owner.fetchGroupPhotos(chatId)).isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect((await owner.fetchGroupPhotos(chatId)).length, 1);
    expect((await third.fetchGroupPhotos(chatId)).length, 1);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('06-native-photo-sent');

    // The open roster must refresh after an independently authenticated join.
    await tester.tap(find.text('Weekend').first);
    await settleUntil(find.text('Group info'));
    final fourthClient = SupabaseClient(url, key);
    addTearDown(fourthClient.dispose);
    await fourthClient.auth.signInWithPassword(
      email: 'dana.groupqa@blab.test',
      password: 'Blab-local-123!',
    );
    await ChatService(fourthClient).joinGroup(token.token);
    await settleUntil(find.text('Dana Local'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('07-native-live-roster');
    await tester.pageBack();
    await tester.pumpAndSettle();
    final scope = ProviderScope.containerOf(
      tester.element(find.byType(ChatScreen)),
    );
    await scope.read(chatListProvider.notifier).refresh();
    router.go('/chats');
    await settleUntil(find.byType(ChatsScreen));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsNothing);
    expect(find.text('Weekend'), findsWidgets);
    await binding.takeScreenshot('03-group-in-chats');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
