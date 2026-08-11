import 'package:blab/features/chat/widgets/message_text.dart';
import 'package:blab/features/chat/widgets/mode_toggle.dart';
import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stand-in [TtsService] that never hits platform channels.
class _FakeTtsService implements TtsService {
  @override
  Future<bool> isLanguageAvailable(String languageCode) async => false;

  @override
  Future<void> speak(String text, String languageCode) async {}

  @override
  Future<void> stop() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('tapping the toggle switches mode and calls set()', (tester) async {
    final fake = _FakeChatModeNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatModeProvider('chat-1').overrideWith(() => fake),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ModeToggle(chatId: 'chat-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Both segment labels are always rendered (it's a two-segment control) —
    // assert on the notifier call, not label presence, to actually exercise
    // the switch rather than passing vacuously.
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);

    // Tap the inactive "Normal" segment directly — tapping the toggle's
    // bounding-box center is unreliable since "Practice" renders wider than
    // "Normal" and can shift the geometric center onto the already-active
    // segment.
    await tester.tap(find.text('Normal'));
    await tester.pumpAndSettle();

    expect(fake.setCalls, [ChatMode.normal]);
  });

  testWidgets('tapping the already-active segment is a no-op', (tester) async {
    final fake = _FakeChatModeNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatModeProvider('chat-1').overrideWith(() => fake),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ModeToggle(chatId: 'chat-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fake.setCalls, isEmpty);

    // Tap the "Practice" segment, which is already active.
    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();

    expect(fake.setCalls, isEmpty);
    expect(find.text('Practice'), findsOneWidget);
  });

  testWidgets('bumps the reset signal before calling set()', (tester) async {
    final container = ProviderContainer(
      overrides: [
        chatModeProvider('chat-1').overrideWith(() => _FakeChatModeNotifier()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: ModeToggle(chatId: 'chat-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(chatModeResetSignalProvider('chat-1')), 0);

    await tester.tap(find.text('Normal'));
    await tester.pumpAndSettle();

    expect(container.read(chatModeResetSignalProvider('chat-1')), 1);
  });

  testWidgets('switching mode dismisses an open word popup', (tester) async {
    final fake = _FakeChatModeNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatModeProvider('chat-1').overrideWith(() => fake),
          ttsServiceProvider.overrideWithValue(_FakeTtsService()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const ModeToggle(chatId: 'chat-1'),
                MessageText(
                  text: 'hallo',
                  tokens: const [
                    MessageToken(text: 'hallo', gloss: 'hello'),
                  ],
                  languageCode: 'de',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('hallo'));
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget); // popup open

    // The popup's own full-screen dismiss barrier sits above everything
    // (it's inserted into the root Overlay), so a real screen tap on
    // "Normal" would hit the barrier first and never reach the toggle —
    // exercising only the barrier's pre-existing tap-outside dismissal,
    // not `_switchTo`'s own `dismissWordPopup()` call this test targets.
    // Invoke the segment's `onTap` directly (bypassing hit-testing) so this
    // test isolates and proves the toggle's own wiring.
    final segmentTap = tester
        .widget<GestureDetector>(
          find
              .ancestor(
                of: find.text('Normal'),
                matching: find.byType(GestureDetector),
              )
              .first,
        )
        .onTap;
    segmentTap!();
    await tester.pumpAndSettle();

    expect(find.text('hello'), findsNothing); // closed by the mode switch
    expect(fake.setCalls, [ChatMode.normal]);
  });
}

class _FakeChatModeNotifier extends ChatModeNotifier {
  _FakeChatModeNotifier() : super('chat-1');
  final List<ChatMode> setCalls = [];
  @override
  ChatMode build() => ChatMode.practice;
  @override
  Future<void> set(ChatMode mode) async {
    setCalls.add(mode);
    state = mode;
  }
}
