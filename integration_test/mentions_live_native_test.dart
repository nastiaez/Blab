import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chat/widgets/mention_picker.dart';
import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:blab/features/chats/chats_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:blab/shared/state/privacy_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:blab/shared/models/message_mention.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('live mention picker send edit readback in both directions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (Uri.parse(url).host != '10.0.2.2') throw StateError('local only');
    await Supabase.initialize(url: url, anonKey: key);
    final bob = Supabase.instance.client, alice = SupabaseClient(url, key);
    addTearDown(alice.dispose);
    await bob.auth.signInWithPassword(
      email: 'bob@blab.test',
      password: 'Blab-local-123!',
    );
    await alice.auth.signInWithPassword(
      email: 'alice@blab.test',
      password: 'Blab-local-123!',
    );
    final owner = ChatService(alice), recipient = ChatService(bob);
    final aid = alice.auth.currentUser!.id, bid = bob.auth.currentUser!.id;
    final chat = await owner.createGroup('Mention acceptance');
    final invite = await owner.createGroupInvite(chat);
    await recipient.joinGroup(invite.token);
    await owner.setLearningLanguage(chatId: chat, langCode: 'en');
    await recipient.setLearningLanguage(chatId: chat, langCode: 'en');
    await recipient.setChatMode(chatId: chat, mode: ChatMode.normal);
    await owner.sendMessage(
      chatId: chat,
      body: '@Bob hello',
      mentions: [MessageMention(userId: bid, label: 'Bob', start: 0)],
    );
    final received = await recipient.fetchMessages(chat);
    expect(
      received
          .firstWhere((m) => m.originalText == '@Bob hello')
          .mentions
          .single
          .userId,
      bid,
    );
    final router = GoRouter(
      initialLocation: '/chat/$chat',
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
    Future<void> until(Finder f) async {
      for (var i = 0; i < 120 && f.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(f, findsWidgets);
    }

    await until(find.text('@Bob'));
    await tester.enterText(
      find.byKey(const ValueKey('composer-message-text-field')),
      '@Ali',
    );
    final candidate = find.descendant(
      of: find.byType(MentionPicker),
      matching: find.text('Alice Local'),
    );
    await until(candidate);
    await tester.tap(candidate);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText))
          .controller
          .text
          .trim(),
      '@Alice',
    );
    await tester.tap(find.byTooltip('Send'));
    FocusManager.instance.primaryFocus?.unfocus();
    await until(find.text('@Alice'));
    await tester.runAsync(() async {
      for (var i = 0; i < 30; i++) {
        final rows = await owner.fetchMessages(chat);
        final reply = rows.where((m) => m.originalText == '@Alice').firstOrNull;
        if (reply != null) {
          expect(reply.mentions.single.userId, aid);
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      fail('tagged reply was not delivered');
    });
    await tester.pump(const Duration(seconds: 1));
    await binding.takeScreenshot('01-live-bob-tagged-reply');
    final reply = (await owner.fetchMessages(
      chat,
    )).firstWhere((m) => m.originalText == '@Alice');
    await recipient.editMessage(
      messageId: reply.id,
      newBody: 'Hi @Alice',
      mentions: [MessageMention(userId: aid, label: 'Alice', start: 3)],
    );
    final edited = (await owner.fetchMessages(
      chat,
    )).firstWhere((m) => m.id == reply.id);
    expect(edited.mentions.single.start, 3);
    expect(edited.mentions.single.userId, aid);
    await recipient.editMessage(messageId: reply.id, newBody: 'Hi Alice');
    expect(
      (await owner.fetchMessages(
        chat,
      )).firstWhere((m) => m.id == reply.id).mentions,
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
