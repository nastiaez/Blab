import 'dart:async';

import 'package:blab/features/chat/state/message_reactions_state.dart';
import 'package:blab/shared/models/message_reaction.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeReactionChatService implements ChatService {
  final changes = StreamController<MessageReactionChange>.broadcast();
  final rows = <Map<String, dynamic>>[];
  final upserts = <({String chatId, String messageId, String emoji})>[];
  final deletes = <({String messageId})>[];

  @override
  Future<List<Map<String, dynamic>>> fetchMessageReactions(
    String chatId,
  ) async {
    return rows;
  }

  @override
  Stream<MessageReactionChange> watchMessageReactionChanges(String chatId) {
    return changes.stream;
  }

  @override
  Future<void> upsertMessageReaction({
    required String chatId,
    required String messageId,
    required String emoji,
  }) async {
    upserts.add((chatId: chatId, messageId: messageId, emoji: emoji));
  }

  @override
  Future<void> deleteMessageReaction({required String messageId}) async {
    deletes.add((messageId: messageId));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Condition was not reached');
}

({
  ProviderSubscription<AsyncValue<Map<String, List<MessageReactionSummary>>>>
  subscription,
  Future<Map<String, List<MessageReactionSummary>>> first,
})
_listenForReactions(ProviderContainer container) {
  final first = Completer<Map<String, List<MessageReactionSummary>>>();
  final subscription = container.listen(messageReactionsProvider('chat-1'), (
    _,
    next,
  ) {
    if (!first.isCompleted && next.hasValue) first.complete(next.value!);
    if (!first.isCompleted && next.hasError) {
      first.completeError(next.error!, next.stackTrace!);
    }
  }, fireImmediately: true);
  return (subscription: subscription, first: first.future);
}

void main() {
  test('aggregates reactions and marks the current user reaction', () async {
    final service = _FakeReactionChatService()
      ..rows.addAll([
        {
          'message_id': 'm1',
          'user_id': 'me',
          'emoji': '❤️',
          'created_at': '2026-08-03T10:00:00Z',
        },
        {
          'message_id': 'm1',
          'user_id': 'them',
          'emoji': '❤️',
          'created_at': '2026-08-03T10:01:00Z',
        },
        {
          'message_id': 'm1',
          'user_id': 'other',
          'emoji': '😂',
          'created_at': '2026-08-03T10:02:00Z',
        },
      ]);
    final container = ProviderContainer(
      overrides: [
        chatServiceProvider.overrideWithValue(service),
        authSessionProvider.overrideWith((ref) => Stream.value(null)),
        currentUserIdProvider.overrideWithValue('me'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await service.changes.close();
    });
    final listener = _listenForReactions(container);
    addTearDown(listener.subscription.close);

    final reactions = await listener.first;

    expect(reactions['m1']!.map((r) => (r.emoji, r.count, r.reactedByMe)), [
      ('❤️', 2, true),
      ('😂', 1, false),
    ]);
  });

  test(
    'selecting the same reaction removes it; another emoji replaces it',
    () async {
      final service = _FakeReactionChatService()
        ..rows.add({
          'message_id': 'm1',
          'user_id': 'me',
          'emoji': '👍',
          'created_at': '2026-08-03T10:00:00Z',
        });
      final container = ProviderContainer(
        overrides: [
          chatServiceProvider.overrideWithValue(service),
          authSessionProvider.overrideWith((ref) => Stream.value(null)),
          currentUserIdProvider.overrideWithValue('me'),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await service.changes.close();
      });
      final listener = _listenForReactions(container);
      addTearDown(listener.subscription.close);

      await listener.first;
      await container
          .read(messageReactionsProvider('chat-1').notifier)
          .react(messageId: 'm1', emoji: '👍');
      expect(service.deletes.single.messageId, 'm1');

      await container
          .read(messageReactionsProvider('chat-1').notifier)
          .react(messageId: 'm1', emoji: '😂');
      expect(service.upserts.single, (
        chatId: 'chat-1',
        messageId: 'm1',
        emoji: '😂',
      ));
    },
  );

  test('realtime updates hydrate the visible reaction chips', () async {
    final service = _FakeReactionChatService();
    final container = ProviderContainer(
      overrides: [
        chatServiceProvider.overrideWithValue(service),
        authSessionProvider.overrideWith((ref) => Stream.value(null)),
        currentUserIdProvider.overrideWithValue('me'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await service.changes.close();
    });
    final listener = _listenForReactions(container);
    addTearDown(listener.subscription.close);

    await listener.first;
    await Future<void>.delayed(Duration.zero);
    service.changes.add(
      const MessageReactionChange.upsert({
        'message_id': 'm1',
        'user_id': 'them',
        'emoji': '🙌',
        'created_at': '2026-08-03T10:00:00Z',
      }),
    );

    await _waitFor(
      () =>
          container
              .read(messageReactionsProvider('chat-1'))
              .value?['m1']
              ?.single
              .emoji ==
          '🙌',
    );
  });
}
