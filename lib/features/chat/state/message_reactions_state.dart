import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/message_reaction.dart';
import '../../../shared/services/local_chat_signals_cache.dart';
import '../../../shared/state/auth_state.dart';
import '../../../shared/state/chat_list_state.dart';

class MessageReactionsNotifier
    extends StreamNotifier<Map<String, List<MessageReactionSummary>>> {
  MessageReactionsNotifier(this.chatId);

  final String chatId;
  final Map<String, MessageReactionRow> _rowsByUserMessage =
      <String, MessageReactionRow>{};
  final Map<String, MessageReactionRow?> _optimistic = {};
  final Map<String, int> _operations = {};
  final Map<String, Future<void>> _commandTails = {};
  int _generation = 0;

  String _key(String messageId, String userId) => '$messageId:$userId';

  Map<String, List<MessageReactionSummary>> _snapshot(String currentUserId) {
    final visible = {..._rowsByUserMessage};
    for (final entry in _optimistic.entries) {
      if (entry.value == null) {
        visible.remove(entry.key);
      } else {
        visible[entry.key] = entry.value!;
      }
    }
    return aggregateMessageReactions(
      visible.values,
      currentUserId: currentUserId,
    );
  }

  void _replaceRows(Iterable<Map<String, dynamic>> rows) {
    _rowsByUserMessage.clear();
    for (final row in rows) {
      final reaction = messageReactionRowFromMap(row);
      if (reaction == null) continue;
      _rowsByUserMessage[_key(reaction.messageId, reaction.userId)] = reaction;
    }
  }

  @override
  Stream<Map<String, List<MessageReactionSummary>>> build() async* {
    final generation = ++_generation;
    _rowsByUserMessage.clear();
    _optimistic.clear();
    _operations.clear();
    _commandTails.clear();
    ref.watch(authSessionProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    if (currentUserId == null) {
      yield const <String, List<MessageReactionSummary>>{};
      return;
    }
    final svc = ref.watch(chatServiceProvider);
    final cache = LocalChatSignalsCache(currentUserId, chatId);
    bool current() =>
        ref.mounted &&
        _generation == generation &&
        ref.read(currentUserIdProvider) == currentUserId;
    final saved = await cache.read('reactions');
    if (!current()) return;
    _replaceRows(saved);
    if (saved.isNotEmpty) yield _snapshot(currentUserId);
    Future<void> persist() => cache.save(
      'reactions',
      _rowsByUserMessage.values.map(
        (row) => {
          'message_id': row.messageId,
          'user_id': row.userId,
          'emoji': row.emoji,
          'created_at': row.createdAt.toUtc().toIso8601String(),
        },
      ),
    );

    try {
      final rows = await svc.fetchMessageReactions(chatId);
      if (!current()) return;
      _replaceRows(rows);
      yield _snapshot(currentUserId);
      await persist();
    } catch (_) {
      if (!current()) return;
      yield _snapshot(currentUserId);
    }

    try {
      await for (final change in svc.watchMessageReactionChanges(chatId)) {
        if (!current()) return;
        switch (change.type) {
          case MessageReactionChangeType.upsert:
            final reaction = messageReactionRowFromMap(change.row!);
            if (reaction != null) {
              _rowsByUserMessage[_key(reaction.messageId, reaction.userId)] =
                  reaction;
            }
            break;
          case MessageReactionChangeType.remove:
            final messageId = change.row?['message_id'];
            final userId = change.row?['user_id'];
            if (messageId is String && userId is String) {
              _rowsByUserMessage.remove(_key(messageId, userId));
            }
            break;
          case MessageReactionChangeType.resync:
            try {
              final rows = await svc.fetchMessageReactions(chatId);
              if (!current()) return;
              _replaceRows(rows);
            } catch (_) {
              continue;
            }
            break;
        }
        yield _snapshot(currentUserId);
        await persist();
      }
    } catch (_) {
      // Keep the last yielded reaction state visible on transient realtime
      // failures. A future provider rebuild or reconnect resync catches up.
    }
  }

  Future<void> react({required String messageId, required String emoji}) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;
    final generation = _generation;
    bool current() =>
        ref.mounted &&
        generation == _generation &&
        ref.read(currentUserIdProvider) == currentUserId;
    final key = _key(messageId, currentUserId);
    final previous = _optimistic.containsKey(key)
        ? _optimistic[key]
        : _rowsByUserMessage[key];
    final sameReaction = previous?.emoji == emoji;
    final next = sameReaction
        ? null
        : MessageReactionRow(
            messageId: messageId,
            userId: currentUserId,
            emoji: emoji,
            createdAt: DateTime.now(),
          );
    final operation = (_operations[key] ?? 0) + 1;
    _operations[key] = operation;
    _optimistic[key] = next;
    state = AsyncData(_snapshot(currentUserId));
    final svc = ref.read(chatServiceProvider);
    final prior = _commandTails[key] ?? Future<void>.value();
    final command = prior.catchError((Object _) {}).then((_) async {
      if (!current()) return;
      if (next == null) {
        await svc.deleteMessageReaction(messageId: messageId);
      } else {
        await svc.upsertMessageReaction(
          chatId: chatId,
          messageId: messageId,
          emoji: emoji,
        );
      }
    });
    _commandTails[key] = command;
    try {
      await command;
      if (!current()) return;
      if (next == null) {
        _rowsByUserMessage.remove(key);
      } else {
        _rowsByUserMessage[key] = next;
      }
      if (_operations[key] == operation) _optimistic.remove(key);
      state = AsyncData(_snapshot(currentUserId));
      await LocalChatSignalsCache(currentUserId, chatId).save(
        'reactions',
        _rowsByUserMessage.values.map(
          (row) => {
            'message_id': row.messageId,
            'user_id': row.userId,
            'emoji': row.emoji,
            'created_at': row.createdAt.toUtc().toIso8601String(),
          },
        ),
      );
    } catch (_) {
      if (current() && _operations[key] == operation) {
        _optimistic.remove(key);
        state = AsyncData(_snapshot(currentUserId));
      }
      rethrow;
    } finally {
      if (current() && identical(_commandTails[key], command)) {
        _commandTails.remove(key);
      }
    }
  }
}

final messageReactionsProvider =
    StreamNotifierProvider.family<
      MessageReactionsNotifier,
      Map<String, List<MessageReactionSummary>>,
      String
    >(MessageReactionsNotifier.new);
