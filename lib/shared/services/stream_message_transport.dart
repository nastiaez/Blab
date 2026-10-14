import 'dart:async';

import 'package:stream_chat/stream_chat.dart' as stream;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/stream_message_mapper.dart';
import '../models/message.dart';
import 'chat_service.dart' show MessageCursor, MessagePage;
import 'stream_chat_session.dart';

class StreamTimelineChange {
  const StreamTimelineChange({
    this.message,
    this.removedId,
    this.resync = false,
  });
  final Message? message;
  final String? removedId;
  final bool resync;
}

/// US-031: transport foundation; canonical chat switching is migration-gated.
class StreamMessageTransport {
  StreamMessageTransport(this._supabase, this._session);
  final SupabaseClient _supabase;
  final StreamChatSession _session;
  final Map<String, Future<stream.Channel>> _channels = {};

  String get _uid {
    final value = _supabase.auth.currentUser?.id;
    if (value == null) throw StateError('not_signed_in');
    // Session checks identity before exposing a connection or cached data.
    _session.client;
    return value;
  }

  Future<stream.Channel> _channel(String chatId) {
    return _channels.putIfAbsent(chatId, () async {
      try {
        await _session.connect();
        final userId = _uid;
        final response = await _supabase.functions.invoke(
          'stream-channel',
          body: {'chatId': chatId},
        );
        final data = response.data;
        if (userId != _uid ||
            response.status != 200 ||
            data is! Map ||
            data['channelType'] != 'blab' ||
            data['channelId'] != chatId) {
          throw StateError('stream_channel_unavailable');
        }
        return _session.client.channel('blab', id: chatId);
      } catch (_) {
        _channels.remove(chatId);
        rethrow;
      }
    });
  }

  Future<MessagePage> fetchPage(
    String chatId, {
    int limit = 50,
    MessageCursor? before,
  }) async {
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    final channel = await _channel(chatId);
    final userId = _uid;
    final rows = <String, stream.Message>{};
    var anchor = before?.id;
    while (rows.length < limit + 1) {
      final remaining = limit + 1 - rows.length;
      final batchLimit = remaining > 100 ? 100 : remaining;
      final state = await channel.query(
        state: true,
        watch: false,
        // Blab has already yielded its account-scoped local snapshot. This
        // query is the background refresh, not another stale-cache read.
        messagesPagination: stream.PaginationParams(
          limit: batchLimit,
          lessThan: anchor,
        ),
      );
      if (_uid != userId) throw StateError('stream_account_changed');
      final batch =
          (state.messages ?? [])
              .where((m) => m.remoteCreatedAt != null)
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final previousCount = rows.length;
      for (final row in batch) {
        rows[row.id] = row;
      }
      if (batch.isEmpty ||
          batch.length < batchLimit ||
          rows.length == previousCount) {
        break;
      }
      anchor = batch.first.id;
    }
    return pageFromStream(
      rows.values,
      chatId: chatId,
      userId: userId,
      limit: limit,
    );
  }

  Stream<StreamTimelineChange> watchTimeline(String chatId) async* {
    final channel = await _channel(chatId);
    final userId = _uid;
    // Subscribe before watch resolves, then signal bounded resync to close the
    // initial snapshot/live-events gap. Cancellation closes the subscription.
    final controller = StreamController<StreamTimelineChange>();
    final subscription = channel.on().listen((event) {
      if (controller.isClosed || _supabase.auth.currentUser?.id != userId) {
        return;
      }
      final source = event.message;
      if (event.type == 'message.deleted' && source != null) {
        controller.add(StreamTimelineChange(removedId: source.id));
      } else if ((event.type == 'message.new' ||
              event.type == 'message.updated') &&
          source != null) {
        final value = messageFromStream(
          source,
          chatId: chatId,
          currentUserId: userId,
        );
        if (value != null) controller.add(StreamTimelineChange(message: value));
      } else if (event.type == 'channel.updated') {
        controller.add(const StreamTimelineChange(resync: true));
      }
    }, onError: controller.addError);
    final reconnect = _session.client.on('connection.recovered').listen((_) {
      if (!controller.isClosed && _supabase.auth.currentUser?.id == userId) {
        controller.add(const StreamTimelineChange(resync: true));
      }
    }, onError: controller.addError);
    try {
      await channel.watch();
      if (_uid != userId) throw StateError('stream_account_changed');
      controller.add(const StreamTimelineChange(resync: true));
      yield* controller.stream;
    } finally {
      await subscription.cancel();
      await reconnect.cancel();
      unawaited(controller.close());
    }
  }

  Stream<Map<String, dynamic>> watchTyping(String chatId) async* {
    final channel = await _channel(chatId);
    final userId = _uid;
    await channel.watch();
    await for (final event in channel.on()) {
      if (_supabase.auth.currentUser?.id != userId) return;
      if (event.type != 'typing.start' && event.type != 'typing.stop') continue;
      final author = event.user?.id;
      if (author != null && author != userId) {
        yield {'user_id': author, 'is_typing': event.type == 'typing.start'};
      }
    }
  }
}

MessagePage pageFromStream(
  Iterable<stream.Message> source, {
  required String chatId,
  required String userId,
  required int limit,
}) {
  final rows = source.where((m) => m.remoteCreatedAt != null).toList()
    ..sort((a, b) {
      final order = a.remoteCreatedAt!.compareTo(b.remoteCreatedAt!);
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
  final hasMore = rows.length > limit;
  final selected = rows.skip(hasMore ? rows.length - limit : 0).toList();
  final oldest = selected.firstOrNull;
  return MessagePage(
    messages: selected
        .map((m) => messageFromStream(m, chatId: chatId, currentUserId: userId))
        .whereType<Message>()
        .toList(),
    hasMore: hasMore,
    nextCursor: oldest == null
        ? null
        : MessageCursor(id: oldest.id, createdAt: oldest.remoteCreatedAt!),
  );
}
