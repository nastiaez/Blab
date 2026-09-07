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

class _RecordingTtsService implements TtsService {
  final List<String> events = <String>[];

  @override
  Future<bool> isLanguageAvailable(String languageCode) async => true;

  @override
  Future<void> speak(String text, String languageCode) async {
    events.add('speak:$languageCode:$text');
  }

  @override
  Future<void> stop() async {
    events.add('stop');
  }

  @override
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
    expect(find.byKey(const ValueKey('word-popup-sound-base')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('word-popup-sound-wave-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('word-popup-sound-wave-2')),
      findsOneWidget,
    );
  });

  testWidgets('tapping another word replaces the open popup in one tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ttsServiceProvider.overrideWithValue(_FakeTtsService())],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MessageText(
                text: 'Hallo Welt',
                tokens: [
                  MessageToken(
                    text: 'Hallo',
                    romanization: 'Hallo',
                    gloss: 'hello',
                  ),
                  MessageToken(text: ' ', isContent: false),
                  MessageToken(
                    text: 'Welt',
                    romanization: 'Welt',
                    gloss: 'world',
                  ),
                ],
                languageCode: 'de',
                style: TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Hallo'));
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);

    await tester.tap(find.text('Welt'));
    await tester.pumpAndSettle();

    expect(find.text('hello'), findsNothing);
    expect(find.text('world'), findsOneWidget);
  });

  testWidgets('word popup uses the approved left-aligned hierarchy', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ttsServiceProvider.overrideWithValue(_FakeTtsService())],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MessageText(
                text: 'காலை',
                tokens: [
                  MessageToken(
                    text: 'காலை',
                    romanization: 'kālai',
                    gloss: 'morning',
                  ),
                ],
                languageCode: 'ta',
                style: TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('காலை'));
    await tester.pumpAndSettle();

    final popupWord = tester.widgetList<Text>(find.text('காலை')).last;
    final transliteration = tester.widget<Text>(find.text('kālai'));
    final translation = tester.widget<Text>(find.text('morning'));

    expect(popupWord.style?.fontSize, 22);
    expect(popupWord.style?.fontWeight, FontWeight.w800);
    expect(popupWord.style?.color, const Color(0xFF1A0A1E));
    expect(transliteration.style?.fontSize, 13);
    expect(transliteration.style?.fontWeight, FontWeight.w400);
    expect(transliteration.style?.color, const Color(0xFF808080));
    expect(translation.style?.fontSize, 14);
    expect(translation.style?.fontWeight, FontWeight.w600);
    expect(translation.style?.color, const Color(0xFF1A0A1E));

    final divider = tester.widget<Container>(
      find.byKey(const ValueKey('word-popup-divider')),
    );
    expect(divider.constraints?.minHeight, 1);
    expect(divider.color, const Color(0xFFE7D7D0));

    final card = tester.widget<Container>(
      find.byKey(const ValueKey('word-popup-card')),
    );
    final decoration = card.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    expect(decoration.color, Colors.white);
    expect(border.top.color, const Color(0xFFE7D7D0));
    expect(border.top.width, 1);

    final wordTopLeft = tester.getTopLeft(find.text('காலை').last);
    final iconTopLeft = tester.getTopLeft(
      find.byKey(const ValueKey('word-popup-sound-base')),
    );
    expect(iconTopLeft.dx, greaterThan(wordTopLeft.dx));
    expect(iconTopLeft.dy, lessThanOrEqualTo(wordTopLeft.dy + 4));

    final tail = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('word-popup-tail')),
    );
    final dynamic painter = tail.painter;
    expect(painter.fillColor, Colors.white);
    expect(painter.strokeColor, const Color(0xFFE7D7D0));
    expect(painter.drawsBaseEdge, isFalse);
  });

  // Mode-display-fixes spec § 2: the padding that used to sit around each
  // word is gone (it inflated the line box). Tap targets must not shrink
  // with it — each word's box still spans the full line height, and a tap
  // away from the word's vertical centre still opens its popup.
  testWidgets('a word keeps a full-line-height tap target', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ttsServiceProvider.overrideWithValue(_FakeTtsService())],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MessageText(
                text: 'காலை எப்படி',
                tokens: [
                  MessageToken(
                    text: 'காலை',
                    romanization: 'kālai',
                    gloss: 'morning',
                  ),
                  MessageToken(text: ' ', isContent: false),
                  MessageToken(
                    text: 'எப்படி',
                    romanization: 'eppadi',
                    gloss: 'how',
                  ),
                ],
                languageCode: 'ta',
                style: TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    );

    final wordRect = tester.getRect(find.text('காலை'));
    final lineRect = tester.getRect(find.byType(MessageText));
    expect(wordRect.height, lineRect.height);

    await tester.tapAt(Offset(wordRect.center.dx, wordRect.top + 5));
    await tester.pumpAndSettle();

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

  testWidgets('speaker tap starts audio without an outside-tap stop race', (
    tester,
  ) async {
    final tts = _RecordingTtsService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ttsServiceProvider.overrideWithValue(tts)],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MessageText(
                text: 'Hola',
                tokens: [
                  MessageToken(
                    text: 'Hola',
                    romanization: 'Hola',
                    gloss: 'Hello',
                  ),
                ],
                languageCode: 'es',
                style: TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Hola'));
    await tester.pumpAndSettle();
    tts.events.clear();

    await tester.tap(find.byType(InkWell).last);
    await tester.pump();

    expect(tts.events, ['speak:es:Hola']);
  });

  testWidgets('tapping outside an open popup stops audio and dismisses it', (
    tester,
  ) async {
    final tts = _RecordingTtsService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ttsServiceProvider.overrideWithValue(tts)],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MessageText(
                text: 'Hallo',
                tokens: [
                  MessageToken(
                    text: 'Hallo',
                    romanization: 'Hallo',
                    gloss: 'Hello',
                  ),
                ],
                languageCode: 'de',
                style: TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Hallo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InkWell).last);
    await tester.pump();
    tts.events.clear();

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(tts.events, ['stop']);
    expect(find.text('Hello'), findsNothing);
  });
}
