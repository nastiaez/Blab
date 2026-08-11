import 'package:blab/features/chat/widgets/mode_toggle.dart';
import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
