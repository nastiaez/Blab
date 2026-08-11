import 'package:blab/features/chat/widgets/message_text.dart';
import 'package:blab/features/chat/widgets/word_popup.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stand-in [TtsService] that never hits platform channels — keeps the
/// widget test free of `MissingPluginException`s.
class _FakeTtsService implements TtsService {
  @override
  Future<bool> isLanguageAvailable(String languageCode) async => false;

  @override
  Future<void> speak(String text, String languageCode) async {}

  @override
  Future<void> stop() async {}

  // Unused but required by interface.
  @override
  // ignore: unused_field
  // ignore: invalid_override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('tapping a content token opens the word popup', (tester) async {
    final message = Message(
      id: 'm1',
      chatId: 'aswin',
      isOutgoing: false,
      originalText: 'காலை எப்படி',
      translation: 'morning how',
      sentAt: DateTime(2026, 5, 25, 9, 30),
      status: MessageStatus.delivered,
      tokens: const [
        MessageToken(text: 'காலை', romanization: 'kālai', gloss: 'morning'),
        MessageToken(text: ' ', isContent: false),
        MessageToken(text: 'எப்படி', romanization: 'eppadi', gloss: 'how'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ttsServiceProvider.overrideWithValue(_FakeTtsService())],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: MessageText(
                text: message.originalText,
                tokens: message.tokens,
                languageCode: 'ta',
                style: const TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    );

    // Popup not yet visible.
    expect(find.text('morning'), findsNothing);

    // Tap the first content word.
    await tester.tap(find.text('காலை'));
    await tester.pumpAndSettle();

    // Popup card surfaces the romanization + English gloss.
    expect(find.text('kālai'), findsOneWidget);
    expect(find.text('morning'), findsOneWidget);
  });

  testWidgets('splits visible text into tappable words without metadata', (
    tester,
  ) async {
    final message = Message(
      id: 'm2',
      chatId: 'aswin',
      isOutgoing: true,
      originalText: 'Hello world',
      translation: '',
      sentAt: DateTime(2026, 5, 25, 9, 31),
      status: MessageStatus.read,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ttsServiceProvider.overrideWithValue(_FakeTtsService())],
        child: MaterialApp(
          home: Scaffold(
            body: MessageText(
              text: message.originalText,
              tokens: message.tokens,
              languageCode: 'en',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('world'), findsOneWidget);

    await tester.tap(find.text('world'));
    await tester.pumpAndSettle();

    expect(find.text('world'), findsWidgets);
  });

  testWidgets('phrase-sized token metadata still leaves words tappable', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ttsServiceProvider.overrideWithValue(_FakeTtsService())],
        child: const MaterialApp(
          home: Scaffold(
            body: MessageText(
              text: 'You can use Google speech.',
              tokens: [
                MessageToken(
                  text: 'You can use Google speech',
                  gloss: 'whole phrase',
                ),
                MessageToken(text: '.', isContent: false),
              ],
              languageCode: 'en',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );

    expect(find.text('You'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('speech'), findsOneWidget);

    await tester.tap(find.text('Google'));
    await tester.pumpAndSettle();

    expect(find.text('Google'), findsWidgets);
    expect(find.text('whole phrase'), findsNothing);
  });

  testWidgets('dismissWordPopup closes an open popup', (tester) async {
    final message = Message(
      id: 'm1',
      chatId: 'aswin',
      isOutgoing: false,
      originalText: 'காலை எப்படி',
      translation: 'morning how',
      sentAt: DateTime(2026, 5, 25, 9, 30),
      status: MessageStatus.delivered,
      tokens: const [
        MessageToken(text: 'காலை', romanization: 'kālai', gloss: 'morning'),
        MessageToken(text: ' ', isContent: false),
        MessageToken(text: 'எப்படி', romanization: 'eppadi', gloss: 'how'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ttsServiceProvider.overrideWithValue(_FakeTtsService())],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: MessageText(
                text: message.originalText,
                tokens: message.tokens,
                languageCode: 'ta',
                style: const TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('காலை'));
    await tester.pumpAndSettle();
    expect(find.text('morning'), findsOneWidget);

    // Design spec § Bubble layout: switching modes closes any open word
    // popup. ModeToggle calls this directly (Task 10 fix) — exercise the
    // exported function itself here rather than round-tripping through a
    // full chat screen.
    dismissWordPopup();
    await tester.pumpAndSettle();

    expect(find.text('morning'), findsNothing);
  });
}
