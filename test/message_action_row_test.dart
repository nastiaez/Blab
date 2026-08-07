import 'package:blab/features/chat/widgets/message_action_row.dart';
import 'package:blab/features/chat/message_actions.dart'
    show MessageAction;
import 'package:blab/shared/models/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Message _message({
  required bool isOutgoing,
  DateTime? sentAt,
  MessageStatus status = MessageStatus.delivered,
}) => Message(
  id: 'm1',
  chatId: 'chat-1',
  isOutgoing: isOutgoing,
  originalText: 'Hello',
  translation: '',
  sentAt: sentAt ?? DateTime.utc(2026, 8, 7, 12),
  status: status,
);

void main() {
  testWidgets('outgoing message shows Reply, Edit, Copy, Delete — not Report', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 7, 12, 5);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageActionRow(
            message: _message(isOutgoing: true, sentAt: now),
            onAction: (_) {},
            now: now,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('message-action-reply')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('message-action-edit')), findsOneWidget);
    expect(find.byKey(const ValueKey('message-action-copy')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('message-action-delete')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('message-action-report')),
      findsNothing,
    );
  });

  testWidgets('incoming message shows Reply, Copy, Report — not Edit/Delete', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageActionRow(
            message: _message(isOutgoing: false),
            onAction: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('message-action-reply')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('message-action-copy')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('message-action-report')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('message-action-edit')), findsNothing);
    expect(
      find.byKey(const ValueKey('message-action-delete')),
      findsNothing,
    );
  });

  // canEditMessage: the 24h messageEditWindow. Outgoing and otherwise
  // eligible, but past the window — Edit drops out, Delete stays.
  testWidgets('outgoing message older than the edit window loses Edit', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 7, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageActionRow(
            message: _message(
              isOutgoing: true,
              sentAt: now.subtract(const Duration(hours: 25)),
            ),
            onAction: (_) {},
            now: now,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('message-action-edit')), findsNothing);
    expect(
      find.byKey(const ValueKey('message-action-delete')),
      findsOneWidget,
    );
  });

  // canReplyToMessage: only delivered/read messages qualify, and
  // canEditMessage is gated on it too.
  testWidgets('still-sending message offers neither Reply nor Edit', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 7, 12, 5);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageActionRow(
            message: _message(
              isOutgoing: true,
              sentAt: now,
              status: MessageStatus.pending,
            ),
            onAction: (_) {},
            now: now,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('message-action-reply')), findsNothing);
    expect(find.byKey(const ValueKey('message-action-edit')), findsNothing);
    expect(find.byKey(const ValueKey('message-action-copy')), findsOneWidget);
  });

  testWidgets('tapping an action fires onAction with that action', (
    tester,
  ) async {
    MessageAction? fired;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageActionRow(
            message: _message(isOutgoing: false),
            onAction: (a) => fired = a,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('message-action-copy')));
    expect(fired, MessageAction.copy);
  });
}
