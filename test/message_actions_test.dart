import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/features/chat/widgets/message_action_sheet.dart';
import 'package:blab/shared/models/message.dart';
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
  group('ChatNotifier — Step 1.7 additions', () {
    test('removeMessage removes the message and returns its index', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Seed an outgoing message.
      container
          .read(chatMessagesProvider('maria').notifier)
          .addOutgoing('hello world');

      final beforeList = container.read(chatMessagesProvider('maria'));
      final target = beforeList.first;
      expect(beforeList.length, 1);

      final idx = container
          .read(chatMessagesProvider('maria').notifier)
          .removeMessage(target.id);
      expect(idx, 0);

      final afterList = container.read(chatMessagesProvider('maria'));
      expect(afterList, isEmpty);
    });

    test('removeMessage returns -1 for an unknown id', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final idx = container
          .read(chatMessagesProvider('maria').notifier)
          .removeMessage('nope');
      expect(idx, -1);
    });

    test('insertMessage restores a removed message at its original index', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(chatMessagesProvider('maria').notifier)
          .addOutgoing('one');
      container
          .read(chatMessagesProvider('maria').notifier)
          .addOutgoing('two');
      container
          .read(chatMessagesProvider('maria').notifier)
          .addOutgoing('three');

      final list = container.read(chatMessagesProvider('maria'));
      final middle = list[1];
      expect(middle.originalText, 'two');

      final idx = container
          .read(chatMessagesProvider('maria').notifier)
          .removeMessage(middle.id);
      expect(idx, 1);
      expect(
          container.read(chatMessagesProvider('maria')).length, 2);

      container
          .read(chatMessagesProvider('maria').notifier)
          .insertMessage(middle, idx);

      final restored = container.read(chatMessagesProvider('maria'));
      expect(restored.length, 3);
      expect(restored[1].id, middle.id);
      expect(restored[1].originalText, 'two');
    });

    test('editMessage updates originalText and flips isEdited', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(chatMessagesProvider('maria').notifier)
          .addOutgoing('typo here');
      final id = container.read(chatMessagesProvider('maria')).first.id;

      container
          .read(chatMessagesProvider('maria').notifier)
          .editMessage(id, 'fixed text');

      final edited = container.read(chatMessagesProvider('maria')).first;
      expect(edited.originalText, 'fixed text');
      expect(edited.isEdited, true);
    });

    test(
        'addOutgoing with replyTo attaches the quoted message to the new bubble',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final quoted = Message(
        id: 'm-orig',
        chatId: 'maria',
        isOutgoing: false,
        originalText: '¡Hola!',
        translation: 'Hi!',
        sentAt: DateTime(2026, 5, 25, 9, 0),
        status: MessageStatus.delivered,
      );

      container
          .read(chatMessagesProvider('maria').notifier)
          .addOutgoing('hey back', replyTo: quoted);

      final list = container.read(chatMessagesProvider('maria'));
      expect(list.length, 1);
      expect(list.first.replyTo, isNotNull);
      expect(list.first.replyTo!.id, 'm-orig');
    });
  });

  group('showMessageActionSheet', () {
    Widget _harness(Widget child) {
      return ProviderScope(
        overrides: [
          ttsServiceProvider.overrideWithValue(_FakeTts()),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      );
    }

    testWidgets('outgoing message shows Reply / Edit / Copy / Delete',
        (tester) async {
      final actions = <MessageAction>[];
      final outgoing = Message(
        id: 'out',
        chatId: 'maria',
        isOutgoing: true,
        originalText: 'mine',
        translation: '',
        sentAt: DateTime(2026, 5, 25),
        status: MessageStatus.read,
      );

      late BuildContext capturedCtx;
      await tester.pumpWidget(_harness(Builder(builder: (ctx) {
        capturedCtx = ctx;
        return const SizedBox.expand();
      })));

      // ignore: unawaited_futures
      showMessageActionSheet(
        capturedCtx,
        message: outgoing,
        onAction: actions.add,
      );
      await tester.pumpAndSettle();

      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('incoming message shows Reply and Copy only', (tester) async {
      final actions = <MessageAction>[];
      final incoming = Message(
        id: 'in',
        chatId: 'aswin',
        isOutgoing: false,
        originalText: 'theirs',
        translation: 'theirs',
        sentAt: DateTime(2026, 5, 25),
        status: MessageStatus.delivered,
      );

      late BuildContext capturedCtx;
      await tester.pumpWidget(_harness(Builder(builder: (ctx) {
        capturedCtx = ctx;
        return const SizedBox.expand();
      })));

      // ignore: unawaited_futures
      showMessageActionSheet(
        capturedCtx,
        message: incoming,
        onAction: actions.add,
      );
      await tester.pumpAndSettle();

      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });
  });

  group('ChatScreen send-with-reply', () {
    testWidgets(
        'tapping send while a reply target is active attaches it to the new outgoing message',
        (tester) async {
      final container = ProviderContainer(overrides: [
        ttsServiceProvider.overrideWithValue(_FakeTts()),
      ]);
      addTearDown(container.dispose);

      // Pre-seed the reply target on the aswin chat.
      final messagesBefore = container.read(chatMessagesProvider('aswin'));
      expect(messagesBefore, isNotEmpty);
      final quoted = messagesBefore.first;
      container.read(replyingToProvider('aswin').notifier).set(quoted);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChatScreen(chatId: 'aswin')),
        ),
      );
      await tester.pump();

      // Find input and type.
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, 'replying to that');
      await tester.pump();

      // Tap the send button (Icons.arrow_upward).
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();

      // Drain the 1500 ms delivered→read timer in `addOutgoing` so the
      // test binding doesn't trip its pending-timer assertion.
      await tester.pump(const Duration(milliseconds: 1600));

      final after = container.read(chatMessagesProvider('aswin'));
      final newOutgoing = after.lastWhere((m) =>
          m.isOutgoing && m.originalText == 'replying to that');
      expect(newOutgoing.replyTo, isNotNull);
      expect(newOutgoing.replyTo!.id, quoted.id);

      // Replying state is cleared after send.
      expect(container.read(replyingToProvider('aswin')), isNull);
    });
  });
}
