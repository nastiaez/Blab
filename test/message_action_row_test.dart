import 'package:blab/features/chat/widgets/message_action_row.dart';
import 'package:blab/features/chat/message_actions.dart' show MessageAction;
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/l10n/l10n.dart';
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

    expect(find.byKey(const ValueKey('message-action-reply')), findsOneWidget);
    expect(find.byKey(const ValueKey('message-action-edit')), findsOneWidget);
    expect(find.byKey(const ValueKey('message-action-copy')), findsOneWidget);
    expect(find.byKey(const ValueKey('message-action-delete')), findsOneWidget);
    expect(find.byKey(const ValueKey('message-action-report')), findsNothing);
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

    expect(find.byKey(const ValueKey('message-action-reply')), findsOneWidget);
    expect(find.byKey(const ValueKey('message-action-copy')), findsOneWidget);
    expect(find.byKey(const ValueKey('message-action-report')), findsOneWidget);
    expect(find.byKey(const ValueKey('message-action-edit')), findsNothing);
    expect(find.byKey(const ValueKey('message-action-delete')), findsNothing);
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
    expect(find.byKey(const ValueKey('message-action-delete')), findsOneWidget);
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

  testWidgets('practice text replaces Original with Listen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageActionRow(
            message: _message(isOutgoing: false),
            mode: ChatMode.practice,
            hasOriginal: true,
            canListen: true,
            onAction: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('message-action-listen')), findsOneWidget);
    expect(find.byKey(const ValueKey('message-action-original')), findsNothing);
  });

  testWidgets('normal text conditionally offers Original', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageActionRow(
            message: _message(isOutgoing: false),
            mode: ChatMode.normal,
            hasOriginal: true,
            canListen: true,
            onAction: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('message-action-original')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('message-action-listen')), findsNothing);
  });

  testWidgets('photo-only messages expose only direction-safe actions', (
    tester,
  ) async {
    final photo = _message(isOutgoing: true).copyWith(
      type: MessageType.image,
      originalText: '',
      attachment: const MessageAttachment(
        id: 'a1',
        messageId: 'm1',
        chatId: 'chat-1',
        storageBucket: 'chat-images',
        storagePath: 'photo.jpg',
        mimeType: 'image/jpeg',
        byteSize: 10,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageActionRow(
            message: photo,
            mode: ChatMode.practice,
            hasOriginal: true,
            canListen: true,
            onAction: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('message-action-reply')), findsOneWidget);
    expect(find.byKey(const ValueKey('message-action-delete')), findsOneWidget);
    expect(find.byKey(const ValueKey('message-action-copy')), findsNothing);
    expect(find.byKey(const ValueKey('message-action-edit')), findsNothing);
    expect(find.byKey(const ValueKey('message-action-listen')), findsNothing);
  });

  testWidgets('five actions remain visible at 200% text scale', (tester) async {
    final now = DateTime.utc(2026, 8, 7, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(375, 780),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: MessageActionRow(
              message: _message(isOutgoing: true, sentAt: now),
              mode: ChatMode.normal,
              hasOriginal: true,
              canListen: true,
              onAction: (_) {},
              now: now,
            ),
          ),
        ),
      ),
    );

    for (final action in ['reply', 'edit', 'copy', 'original', 'delete']) {
      expect(find.byKey(ValueKey('message-action-$action')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('five actions remain fully visible in all launch UI languages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.utc(2026, 8, 7, 12);

    for (final locale in const [
      Locale('en'),
      Locale('de'),
      Locale('es'),
      Locale('uk'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(375, 780),
              textScaler: TextScaler.noScaling,
            ),
            child: Scaffold(
              body: MessageActionRow(
                message: _message(isOutgoing: true, sentAt: now),
                mode: ChatMode.normal,
                hasOriginal: true,
                canListen: true,
                onAction: (_) {},
                now: now,
              ),
            ),
          ),
        ),
      );

      final labels = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(MessageActionRow),
              matching: find.byType(Text),
            ),
          )
          .toList();
      expect(labels, hasLength(5));
      for (final label in labels) {
        expect(label.maxLines, 2);
        expect(label.overflow, isNull);
      }
      expect(tester.takeException(), isNull);
    }
  });
}
