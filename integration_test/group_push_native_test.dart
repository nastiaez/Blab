import 'package:blab/app/router.dart';
import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chats/chats_screen.dart';
import 'package:blab/features/onboarding/state/onboarding_destination.dart';
import 'package:blab/features/onboarding/state/onboarding_destination_state.dart';
import 'package:blab/main.dart' as app;
import 'package:blab/shared/data/firebase_config.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/services/push_notification_gateway.dart';
import 'package:blab/shared/services/push_token_repository.dart';
import 'package:blab/shared/state/push_notifications_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Local QA enables the real SDK without changing the release's push gates.
class _LocalPushGateway extends FirebasePushNotificationGateway {
  @override
  bool get isSupported => true;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real group FCM notification tap opens its group', (
    tester,
  ) async {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (Uri.parse(url).host != '10.0.2.2') throw StateError('Local QA only');
    expect(
      await initializeFirebaseForPush(
        enabled: true,
        expectedProjectId: 'blab-nastia-ez',
        requiredForHostedAndroid: true,
      ),
      isTrue,
    );
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
    final viewer = ChatService(alice);
    final id = await owner.createGroup('Notification test');
    final invite = await owner.createGroupInvite(id);
    await viewer.joinGroup(invite.token);
    await viewer.setLearningLanguage(chatId: id, langCode: 'de');
    await viewer.setChatMode(chatId: id, mode: ChatMode.normal);
    final gateway = _LocalPushGateway();
    expect(
      await gateway.requestPermission(),
      PushAuthorizationStatus.authorized,
    );
    final token = await gateway.getToken();
    expect(token, isNotEmpty);
    final repository = SupabasePushTokenRepository(alice);
    await repository.register(token: token!, previewsEnabled: true);
    addTearDown(() => repository.unregister(token));
    await binding.convertFlutterSurfaceToImage();
    blabRouter.go('/chats');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pushNotificationGatewayProvider.overrideWithValue(gateway),
          onboardingDestinationProvider.overrideWith(
            (ref) async => OnboardingDestination.chats,
          ),
        ],
        child: const app.BlabApp(),
      ),
    );
    Future<void> until(Finder finder) async {
      for (var i = 0; i < 200 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(finder, findsWidgets);
    }

    await until(find.byType(ChatsScreen));
    final opened = gateway.onOpenEvent.first.timeout(
      const Duration(seconds: 90),
    );
    debugPrint('GROUP_PUSH_READY:$id');
    final event = await tester.runAsync(() => opened);
    expect(event?.chatId, id);
    expect(event?.receiverId, alice.auth.currentUser!.id);
    await until(find.byType(ChatScreen));
    await until(find.text('A real group notification.'));
    expect(blabRouter.routeInformationProvider.value.uri.path, '/chat/$id');
    await tester.pumpAndSettle();
    await binding.takeScreenshot('01-real-group-notification-opened');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
