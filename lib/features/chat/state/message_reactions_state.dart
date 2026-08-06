import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/message_reaction.dart';
import '../../../shared/state/auth_state.dart';
import '../../../shared/state/chat_list_state.dart';

class MessageReactionsNotifier
    extends StreamNotifier<Map<String, List<MessageReactionSummary>>> {
  MessageReactionsNotifier(this.chatId);

  final String chatId;
  final Map<String, MessageReactionRow> _rowsByUserMessage =
      <String, MessageReactionRow>{};

  String _key(String messageId, String userId) => '$messageId:$userId';

  Map<String, List<MessageReactionSummary>> _snapshot(String currentUserId) {
    return aggregateMessageReactions(
      _rowsByUserMessage.values,
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
    ref.watch(authSessionProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    if (currentUserId == null) {
      yield const <String, List<MessageReactionSummary>>{};
      return;
    }
    final svc = ref.watch(chatServiceProvider);

    try {
      _replaceRows(await svc.fetchMessageReactions(chatId));
      yield _snapshot(currentUserId);
    } catch (_) {
      yield const <String, List<MessageReactionSummary>>{};
    }

    try {
      await for (final change in svc.watchMessageReactionChanges(chatId)) {
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
              _replaceRows(await svc.fetchMessageReactions(chatId));
            } catch (_) {
              continue;
            }
            break;
        }
        yield _snapshot(currentUserId);
      }
    } catch (_) {
      // Keep the last yielded reaction state visible on transient realtime
      // failures. A future provider rebuild or reconnect resync catches up.
    }
  }

  Future<void> react({required String messageId, required String emoji}) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;
    final key = _key(messageId, currentUserId);
    final previous = _rowsByUserMessage[key];
    final sameReaction = previous?.emoji == emoji;
    try {
      if (sameReaction) {
        _rowsByUserMessage.remove(key);
        state = AsyncData(_snapshot(currentUserId));
        await ref
            .read(chatServiceProvider)
            .deleteMessageReaction(messageId: messageId);
        return;
      }
      _rowsByUserMessage[key] = MessageReactionRow(
        messageId: messageId,
        userId: currentUserId,
        emoji: emoji,
        createdAt: previous?.createdAt ?? DateTime.now(),
      );
      state = AsyncData(_snapshot(currentUserId));
      await ref
          .read(chatServiceProvider)
          .upsertMessageReaction(
            chatId: chatId,
            messageId: messageId,
            emoji: emoji,
          );
    } catch (_) {
      if (previous == null) {
        _rowsByUserMessage.remove(key);
      } else {
        _rowsByUserMessage[key] = previous;
      }
      state = AsyncData(_snapshot(currentUserId));
      rethrow;
    }
  }
}

final messageReactionsProvider =
    StreamNotifierProvider.family<
      MessageReactionsNotifier,
      Map<String, List<MessageReactionSummary>>,
      String
    >(MessageReactionsNotifier.new);
