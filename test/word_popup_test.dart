import 'package:blab/features/chat/widgets/message_text.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stand-in [TtsService] that never hits platform channels — keeps the
/// widget test free of `MissingPluginException`s.
class _FakeTtsService implements TtsService {
  bool available;
  _FakeTtsService({this.available = false});

  @override
  Future<bool> isLanguageAvailable(String languageCode) async => available;

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
  testWidgets('tapping a content token opens the word popup',
      (tester) async {
    final message = Message(
      id: 'm1',
      chatId: 'aswin',
      isOutgoing: false,
      originalText: 'காலை எப்படி',
      translation: 'morning how',
      sentAt: DateTime(2026, 5, 25, 9, 30),
      status: MessageStatus.delivered,
      tokens: const [
        MessageToken(text: 'காலை', romanization: 'kālai', english: 'morning'),
        MessageToken(text: ' ', isContent: false),
        MessageToken(text: 'எப்படி', romanization: 'eppadi', english: 'how'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsServiceProvider.overrideWithValue(_FakeTtsService()),
        ],
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

  testWidgets('falls back to plain Text when tokens are null',
      (tester) async {
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
        overrides: [
          ttsServiceProvider.overrideWithValue(_FakeTtsService()),
        ],
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

    expect(find.text('Hello world'), findsOneWidget);
  });
}
