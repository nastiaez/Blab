import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/services/tts_service.dart';
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
  group('learningLanguageProvider', () {
    test('seeds the Aswin chat with Tamil from kMockChats', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final lang = container.read(learningLanguageProvider('aswin'));
      expect(lang.code, 'ta');
    });

    test('seeds the Maria chat with Spanish from kMockChats', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final lang = container.read(learningLanguageProvider('maria'));
      expect(lang.code, 'es');
    });

    test('falls back to English for unknown chat ids', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final lang = container.read(learningLanguageProvider('nope'));
      expect(lang.code, 'en');
    });

    test('set() mutates state for that chat only', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final french = kBlabLanguages.firstWhere((l) => l.code == 'fr');
      container
          .read(learningLanguageProvider('aswin').notifier)
          .set(french);

      expect(container.read(learningLanguageProvider('aswin')).code, 'fr');
      // Other chats are independent.
      expect(container.read(learningLanguageProvider('maria')).code, 'es');
    });
  });

  group('ChatScreen — change learning language flow', () {
    testWidgets(
        'picking a language from the sheet updates header subtitle and menu label',
        (tester) async {
      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(_FakeTts()),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChatScreen(chatId: 'aswin')),
        ),
      );
      await tester.pumpAndSettle();

      // Header now just shows the partner name + online state — the
      // "Learning …" subtitle moved into the ··· menu + partner profile sheet.
      expect(find.text('Aswin'), findsOneWidget);

      // Open the ··· menu.
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      // Menu shows the current language label on the right.
      expect(find.text('Learning language'), findsOneWidget);
      expect(find.text('Tamil'), findsOneWidget);

      // Tap the "Learning language" menu row to open the sheet.
      await tester.tap(find.text('Learning language'));
      await tester.pumpAndSettle();

      // Sheet heading is "Learning language" (sheet has its own heading too).
      expect(find.text('Learning language'), findsWidgets);

      // Spanish may be off-screen depending on viewport size — scroll the
      // sheet list into view first.
      await tester.scrollUntilVisible(
        find.text('Spanish'),
        100,
        scrollable: find.byType(Scrollable).last,
      );

      // Pick Spanish from the sheet.
      await tester.tap(find.text('Spanish'));
      await tester.pumpAndSettle();

      // Reopen the menu — label should now say Spanish.
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      expect(find.text('Spanish'), findsWidgets);
      expect(find.text('Tamil'), findsNothing);

      // Provider state is also updated.
      expect(
          container.read(learningLanguageProvider('aswin')).code, 'es');
    });

    testWidgets(
        'tapping Done in the sheet closes it without changing the language',
        (tester) async {
      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(_FakeTts()),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChatScreen(chatId: 'aswin')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Learning language'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(
          container.read(learningLanguageProvider('aswin')).code, 'ta');
    });
  });
}
