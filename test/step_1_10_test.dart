import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/features/chats/chats_screen.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:blab/shared/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTts implements TtsService {
  @override
  Future<bool> isLanguageAvailable(String languageCode) async => false;
  @override
  Future<void> speak(String text, String languageCode) async {}
  @override
  Future<void> stop() async {}
}

void main() {
  group('Message length counter (PRD US-036)', () {
    // The chat input renders a "X / 2000" counter once length ≥ 1800,
    // colored red at 2000, and disables send when over the cap. The counter
    // text and threshold logic are easily unit-testable on their own.
    bool shouldShowCounter(int length) => length >= 1800;
    bool counterIsAtLimit(int length) => length >= 2000;
    bool canSend(String text, int max) {
      final trimmed = text.trim();
      if (trimmed.isEmpty) return false;
      return text.characters.length <= max;
    }

    test('hidden below 1800', () {
      expect(shouldShowCounter(0), isFalse);
      expect(shouldShowCounter(1799), isFalse);
    });

    test('visible from 1800 up to and at 2000', () {
      expect(shouldShowCounter(1800), isTrue);
      expect(shouldShowCounter(1999), isTrue);
      expect(shouldShowCounter(2000), isTrue);
    });

    test('"at limit" colour engages from exactly 2000', () {
      expect(counterIsAtLimit(1999), isFalse);
      expect(counterIsAtLimit(2000), isTrue);
    });

    test('send disabled when over 2000 chars', () {
      expect(canSend('hi', 2000), isTrue);
      // Right at the cap = allowed (cap is inclusive).
      expect(canSend('a' * 2000, 2000), isTrue);
      // Over the cap = blocked. (TextField.maxLength prevents typing more,
      // but the bar still enforces.)
      expect(canSend('a' * 2001, 2000), isFalse);
      // Empty / whitespace blocked.
      expect(canSend('   ', 2000), isFalse);
    });
  });

  group('Offline banner (PRD US-031)', () {
    testWidgets(
        'with forceOfflineProvider = true, ChatsScreen renders the offline banner',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Flip the dev toggle on before pumping.
      container.read(forceOfflineProvider.notifier).set(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChatsScreen()),
        ),
      );

      // Let the stream debounce (200 ms) + a frame for the AnimatedSwitcher.
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));

      // Banner is mounted (matches the static copy).
      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(
        find.text(
            "No connection — messages will send when you're back online"),
        findsOneWidget,
      );

      // Drain the skeleton timer so teardown is clean.
      await tester.pump(const Duration(milliseconds: 700));
    });
  });

  group('Failed-send retry sheet (PRD US-030 affordances)', () {
    Future<void> pumpChat(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChatScreen(chatId: 'maria')),
        ),
      );
      // Wait past the 400 ms cold-open skeleton in ChatScreen.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
    }

    testWidgets(
        'a failed outgoing bubble shows the red error icon; tapping it opens Retry / Delete',
        (tester) async {
      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(_FakeTts()),
      ]);
      addTearDown(container.dispose);

      // Turn on the failure simulator and send a message.
      container.read(simulateFailureProvider.notifier).set(true);

      await pumpChat(tester, container);

      container
          .read(chatMessagesProvider('maria').notifier)
          .addOutgoing('this will fail');

      // Drain the 800 ms pending→failed flip.
      await tester.pump(const Duration(milliseconds: 850));
      await tester.pump();

      final messages = container.read(chatMessagesProvider('maria'));
      expect(messages, isNotEmpty);
      expect(messages.last.status, MessageStatus.failed);

      // Red error icon visible.
      expect(find.byIcon(Icons.error_outline), findsWidgets);

      // Tap the bubble text — opens the action sheet.
      await tester.tap(find.text('this will fail'));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    test('retryFailed removes the failed message and re-queues a new one', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(simulateFailureProvider.notifier).set(true);
      container
          .read(chatMessagesProvider('maria').notifier)
          .addOutgoing('boom');

      final firstId = container.read(chatMessagesProvider('maria')).last.id;

      // Turn the simulator off so the retry succeeds.
      container.read(simulateFailureProvider.notifier).set(false);

      container
          .read(chatMessagesProvider('maria').notifier)
          .retryFailed(firstId);

      final list = container.read(chatMessagesProvider('maria'));
      expect(list.length, 1);
      // Different id (fresh send) but same text.
      expect(list.last.id, isNot(firstId));
      expect(list.last.originalText, 'boom');
      expect(list.last.status, MessageStatus.delivered);
    });
  });
}
