import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/features/chats/chats_screen.dart';
import 'package:blab/features/chats/widgets/chat_list_tile.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeTts implements TtsService {
  @override
  Future<bool> isLanguageAvailable(String languageCode) async => false;
  @override
  Future<void> speak(String text, String languageCode) async {}
  @override
  Future<void> stop() async {}
}

void main() {
  testWidgets(
      "/chats?as=aswin shows exactly one Nastia tile with a New pill",
      (tester) async {
    final router = GoRouter(
      initialLocation: '/chats?as=aswin',
      routes: [
        GoRoute(
          path: '/chats',
          builder: (context, state) => ChatsScreen(
            asAswin: state.uri.queryParameters['as'] == 'aswin',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // Exactly one ChatListTile renders.
    expect(find.byType(ChatListTile), findsOneWidget);

    // It says "Nastia".
    expect(find.text('Nastia'), findsOneWidget);

    // The trailing "New" pill is visible.
    expect(find.text('New'), findsOneWidget);
  });

  testWidgets(
      'Aswin chat /chat/nastia shows the exchange card; first send removes it',
      (tester) async {
    final container = ProviderContainer(overrides: [
      ttsServiceProvider.overrideWithValue(_FakeTts()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ChatScreen(chatId: 'nastia')),
      ),
    );
    await tester.pumpAndSettle();

    // Exchange card content is on screen.
    expect(find.text('You learn Ukrainian'), findsOneWidget);
    expect(find.text('Help Nastia learn Tamil'), findsOneWidget);

    // Send a message via the provider — this is the same effect as typing
    // and tapping the send button.
    container
        .read(chatMessagesProvider('nastia').notifier)
        .addOutgoing('hi');
    await tester.pump();

    // Exchange card gone now that there is at least one message.
    expect(find.text('You learn Ukrainian'), findsNothing);
    expect(find.text('Help Nastia learn Tamil'), findsNothing);
    expect(find.text('hi'), findsOneWidget);

    // Drain the 1500ms delivered→read transition timer so the fake-async
    // binding doesn't complain about pending timers at test teardown.
    await tester.pump(const Duration(milliseconds: 1600));
  });
}
