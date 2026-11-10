import 'dart:io';
import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chats/chats_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:blab/shared/state/privacy_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Local-only real Auth/PostgREST/RLS/chat services; no injected persistence or
// translation payload. Provider credentials are absent on this isolated stack.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('BLA42 real Alice/Bob exact address actions', (tester) async {
    const url = String.fromEnvironment(
      'BLA42_LOCAL_URL',
      defaultValue: String.fromEnvironment('SUPABASE_URL'),
    );
    const key = String.fromEnvironment(
      'BLA42_LOCAL_KEY',
      defaultValue: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    );
    if (!{'127.0.0.1', 'localhost', '10.0.2.2'}.contains(Uri.parse(url).host)) {
      throw StateError('local backend only');
    }
    await Supabase.initialize(url: url, anonKey: key);
    final bob = Supabase.instance.client;
    final alice = SupabaseClient(url, key);
    addTearDown(alice.dispose);
    await bob.auth.signInWithPassword(
      email: 'bob@blab.test',
      password: 'Blab-local-123!',
    );
    await alice.auth.signInWithPassword(
      email: 'alice@blab.test',
      password: 'Blab-local-123!',
    );
    final a = ChatService(alice), b = ChatService(bob);
    final chat = await a.createGroup('BLA42 real address acceptance');
    final invite = await a.createGroupInvite(chat);
    await b.joinGroup(invite.token);
    await a.setLearningLanguage(chatId: chat, langCode: 'en');
    await b.setLearningLanguage(chatId: chat, langCode: 'en');
    await a.setChatMode(chatId: chat, mode: ChatMode.normal);
    await b.setChatMode(chatId: chat, mode: ChatMode.normal);
    await a.sendMessage(
      chatId: chat,
      body: 'Furkastrasse 82 this is my address',
    );
    expect(
      (await b.fetchMessages(
        chat,
      )).any((m) => m.originalText == 'Furkastrasse 82 this is my address'),
      isTrue,
    );
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    Future<void> ready(Finder f) async {
      for (var i = 0; i < 180 && f.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(f, findsWidgets);
    }

    Future<void> mount(SupabaseClient client) async {
      final router = GoRouter(
        initialLocation: '/chat/$chat',
        routes: [
          GoRoute(
            path: '/chat/:id',
            builder: (_, s) => ChatScreen(chatId: s.pathParameters['id']!),
          ),
          GoRoute(path: '/chats', builder: (_, _) => const ChatsScreen()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            supabaseClientProvider.overrideWithValue(client),
            isOnlineProvider.overrideWithValue(true),
            typingIndicatorsEnabledProvider.overrideWithValue(false),
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
      await ready(find.byKey(const ValueKey('composer-message-text-field')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> copyAddress(String address, String evidence) async {
      final rich = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains(address),
      );
      await ready(rich);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 1)),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('$evidence-before-tap');
      final p = tester.renderObject<RenderParagraph>(rich.first);
      final text = tester.widget<RichText>(rich.first).text.toPlainText();
      final start = text.indexOf(address);
      final box = p
          .getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: start + 1),
          )
          .first;
      debugPrint(
        'BLA42_LIVE_TARGET text=$text point=${p.localToGlobal(box.toRect().center)} richCount=${rich.evaluate().length}',
      );
      await tester.tapAt(p.localToGlobal(box.toRect().center));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 800)),
      );
      await tester.pumpAndSettle();
      await ready(find.text('Copy address'));
      await tester.pump(const Duration(milliseconds: 500));
      await binding.takeScreenshot('$evidence-popup');
      await tester.tap(find.text('Copy address'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 900)),
      );
      expect((await Clipboard.getData(Clipboard.kTextPlain))?.text, address);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('$evidence-copied');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 5)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Address copied'), findsNothing);
    }

    await mount(bob);
    await copyAddress('Furkastrasse 82', '01-bob-received');
    await tester.enterText(
      find.byKey(const ValueKey('composer-message-text-field')),
      '123 Main Street reply from Bob',
    );
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02-bob-composer-ready');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (var i = 0; i < 40; i++) {
        if ((await a.fetchMessages(
          chat,
        )).any((m) => m.originalText == '123 Main Street reply from Bob')) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      fail('Bob composer reply absent from real Alice readback');
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await mount(alice);
    await copyAddress('123 Main Street', '02-alice-received');
    debugPrint('BLA42_REAL_AUTH_CHAT_BIDIRECTIONAL_COPY_PASS chat=$chat');
    final destination = find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains('123 Main Street'),
    );
    final paragraph = tester.renderObject<RenderParagraph>(destination.first);
    final rendered = tester
        .widget<RichText>(destination.first)
        .text
        .toPlainText();
    final start = rendered.indexOf('123 Main Street');
    final box = paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + 1),
        )
        .first;
    await tester.tapAt(paragraph.localToGlobal(box.toRect().center));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 800)),
    );
    await tester.pumpAndSettle();
    await ready(find.text('Open in Google Maps'));
    await binding.takeScreenshot('03-live-maps-action');
    await tester.tap(find.text('Open in Google Maps'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 5)),
    );
    debugPrint(
      'BLA42_LIVE_NATIVE_MAPS_HANDOFF_REQUESTED query=123 Main Street',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
