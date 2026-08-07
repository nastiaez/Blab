import 'package:blab/features/chat/widgets/message_action_row.dart';
import 'package:blab/features/chat/message_actions.dart'
    show MessageAction;
import 'package:blab/shared/models/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Message _message({required bool isOutgoing, DateTime? sentAt}) => Message(
  id: 'm1',
  chatId: 'chat-1',
  isOutgoing: isOutgoing,
  originalText: 'Hello',
  translation: '',
  sentAt: sentAt ?? DateTime.utc(2026, 8, 7, 12),
  status: MessageStatus.delivered,
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
