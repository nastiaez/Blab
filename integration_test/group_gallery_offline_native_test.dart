import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/groups/group_info_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('101-photo Android gallery and actual device-offline retention', (
    tester,
  ) async {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const group = String.fromEnvironment('GROUP_GALLERY_QA_ID');
    if (Uri.parse(url).host != '10.0.2.2' || group.isEmpty) {
      throw StateError('Local QA only');
    }
    await Supabase.initialize(url: url, anonKey: key);
    final client = Supabase.instance.client;
    await client.auth.signInWithPassword(
      email: 'alice@blab.test',
      password: 'Blab-local-123!',
    );
    final service = ChatService(client);
    final photos = await service.fetchGroupPhotos(group);
    expect(photos.length, greaterThanOrEqualTo(101));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final online = container.listen(
      onlineProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(online.close);
    final chat = (await container.read(
      chatListProvider.future,
    )).singleWhere((c) => c.id == group);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: blabTheme,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GroupInfoScreen(chat: chat),
        ),
      ),
    );
    Future<void> until(Finder finder) async {
      for (var i = 0; i < 200 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(finder, findsWidgets);
      await tester.pump(const Duration(milliseconds: 400));
    }

    await until(find.text('SHARED MEDIA · ${photos.length}'));
      await tester.tap(find.text('See all').first);
    await tester.pumpAndSettle();
    final finalPhoto = find.byWidgetPredicate(
      (w) => w is PhotoMessageView && w.attachment.id == photos.last.id,
    );
      await tester.scrollUntilVisible(finalPhoto, 500, maxScrolls: 60,
          scrollable: find.byType(Scrollable).first);
    await until(finalPhoto.hitTestable());
    await tester.pumpAndSettle();
    await binding.takeScreenshot('01-native-gallery-final-page');
    await tester.tap(finalPhoto.hitTestable());
    await until(find.byType(PhotoViewerScreen));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02-native-oldest-photo-viewer');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    debugPrint('GROUP_OFFLINE_READY');
    for (var i = 0; i < 200 && container.read(isOnlineProvider); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(container.read(isOnlineProvider), isFalse);
    await expectLater(
      service.fetchGroupMembers(group).timeout(const Duration(seconds: 4)),
      throwsA(isA<Exception>()),
    );
    container.invalidate(groupMembersProvider(group));
    container.invalidate(groupPhotosProvider(group));
    await until(find.text('SHARED MEDIA · ${photos.length}'));
    expect(find.text(chat.partnerName), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await binding.takeScreenshot('03-native-device-offline-retained-info');
    debugPrint('GROUP_OFFLINE_VERIFIED');
    for (var i = 0; i < 300 && !container.read(isOnlineProvider); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(container.read(isOnlineProvider), isTrue);
    expect(await service.fetchGroupMembers(group), isNotEmpty);
    await until(find.text('SHARED MEDIA · ${photos.length}'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('04-native-connectivity-restored');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
