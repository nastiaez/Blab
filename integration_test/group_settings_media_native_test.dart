import 'dart:io';
import 'package:blab/app/app_messenger.dart';
import 'package:blab/app/telegram_route.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/groups/group_info_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real group photos, live refresh, viewer and per-member mute', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (!['10.0.2.2', '127.0.0.1'].contains(Uri.parse(url).host)) {
      throw StateError('Local QA only');
    }
    await Supabase.initialize(url: url, anonKey: key);
    final bob = Supabase.instance.client;
    final alice = SupabaseClient(url, key);
    final carol = SupabaseClient(url, key);
    addTearDown(alice.dispose);
    addTearDown(carol.dispose);
    for (final account in [(alice, 'alice'), (bob, 'bob'), (carol, 'carol')]) {
      await account.$1.auth.signInWithPassword(
        email: '${account.$2}@blab.test',
        password: 'Blab-local-123!',
      );
    }
    final owner = ChatService(alice);
    final viewer = ChatService(bob);
    final newcomer = ChatService(carol);
    final id = await owner.createGroup('Weekend');
    final invite = await owner.createGroupInvite(id);
    await viewer.joinGroup(invite.token);
    final data = await rootBundle.load('assets/onboarding/reading-nook.png');
    final fixture = PickedChatImage(
      bytes: Uint8List.sublistView(data),
      mimeType: 'image/png',
      fileName: 'local-sample.png',
    );
    final beforeJoin = await owner.sendPhotoMessage(
      chatId: id,
      image: fixture,
      caption: 'Before Carol joins',
    );
    await newcomer.joinGroup(invite.token);
    expect((await newcomer.fetchGroupPhotos(id)).length, 1);
    final historicalBytes = await carol.storage
        .from(beforeJoin.attachment.storageBucket)
        .download(beforeJoin.attachment.storagePath);
    expect(historicalBytes.length, fixture.bytes.length);
    final sent = await owner.sendPhotoMessage(
      chatId: id,
      image: fixture,
      caption: 'Shared sample',
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final chat = (await container.read(
      chatListProvider.future,
    )).singleWhere((c) => c.id == id);
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: blabTheme,
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: appMessengerKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(telegramRoute<void>(GroupInfoScreen(chat: chat))),
                  child: const Text('Open group'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Future<void> until(Finder finder) async {
      for (var i = 0; i < 150 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(finder, findsWidgets);
    }

    await tester.tap(find.text('Open group'));
    await until(find.text('SHARED MEDIA · 2'));
    await until(find.text('On'));
    await owner.sendPhotoMessage(
      chatId: id,
      image: fixture,
      caption: 'Arrives while open',
    );
    await until(find.text('SHARED MEDIA · 3'));
    expect((await newcomer.fetchGroupPhotos(id)).length, 3);
    expect((await viewer.fetchGroupPhotos(id)).length, 3);
    // Distinct account can read the real persisted object, not only a cached preview.
    final bytes = await carol.storage
        .from(sent.attachment.storageBucket)
        .download(sent.attachment.storagePath);
    expect(bytes.length, fixture.bytes.length);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('01-group-info-photos');
    final notifications = find.byKey(const ValueKey('group-notifications'));
    await tester.ensureVisible(notifications);
    await tester.pumpAndSettle();
    await tester.tap(notifications);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<bool>, 'Off'));
    await tester.pumpAndSettle();
    expect(await viewer.fetchGroupNotifications(id), isFalse);
    expect(await owner.fetchGroupNotifications(id), isTrue);
    await binding.takeScreenshot('02-notifications-off');
    await tester.scrollUntilVisible(find.text('See all'), -200);
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('03-all-group-photos');
    await tester.tap(find.byType(PhotoMessageView).first);
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewerScreen), findsOneWidget);
    await binding.takeScreenshot('04-photo-viewer');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(PhotoMessageView), findsNWidgets(3));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
