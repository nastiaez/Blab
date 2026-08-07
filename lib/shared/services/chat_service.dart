import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/chat_mappers.dart';
import '../models/message.dart';
import '../models/message_reaction.dart';

typedef CachedMessageTranslation = ({
  String text,
  String interfaceText,
  String interfaceLang,
  String sourceLang,
  String mode,
  String? explanation,
  String? confidence,
  List<Map<String, dynamic>> tokens,
});

String _newStorageSafeId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

String _extensionForMime(String mimeType) => switch (mimeType) {
  'image/png' => 'png',
  'image/webp' => 'webp',
  'image/gif' => 'gif',
  _ => 'jpg',
};

class MessageTranslationChange {
  const MessageTranslationChange({
    required this.messageId,
    required this.targetLang,
    required this.interfaceLang,
    required this.translation,
  });

  final String messageId;
  final String targetLang;
  final String interfaceLang;
  final CachedMessageTranslation translation;
}

/// Public-facing invite metadata returned by [ChatService.getInvite].
class InviteMetadata {
  const InviteMetadata({
    required this.token,
    required this.inviterUserId,
    required this.inviterName,
    required this.inviterLearningLanguage,
    required this.expiresAt,
    required this.status,
    this.resultingChatId,
    this.claimedByName,
  });

  final String token;
  final String inviterUserId;
  final String inviterName;
  final String inviterLearningLanguage;
  final DateTime expiresAt;

  /// One of `valid`, `expired`, `used`.
  final String status;

  /// Chat created when the invite was claimed (only populated when
  /// `status == 'used'`).
  final String? resultingChatId;

  /// Display name of the user who accepted the invite (only populated
  /// when `status == 'used'`).
  final String? claimedByName;
}

class MessageCursor {
  const MessageCursor({required this.createdAt, required this.id});

  final DateTime createdAt;
  final String id;
}

class MessagePage {
  const MessagePage({
    required this.messages,
    required this.hasMore,
    this.nextCursor,
  });

  final List<Message> messages;
  final bool hasMore;
  final MessageCursor? nextCursor;
}

enum MessageChangeType { upsert, remove, resync }

class MessageChange {
  const MessageChange._(this.type, this.row);

  const MessageChange.upsert(Map<String, dynamic> row)
    : this._(MessageChangeType.upsert, row);

  const MessageChange.remove(Map<String, dynamic> row)
    : this._(MessageChangeType.remove, row);

  const MessageChange.resync() : this._(MessageChangeType.resync, null);

  final MessageChangeType type;
  final Map<String, dynamic>? row;
}

class PickedChatImage {
  const PickedChatImage({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
  });

  final Uint8List bytes;
  final String mimeType;
  final String fileName;
}

class ChatService {
  ChatService(this._client);
  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('not_signed_in');
    return id;
  }

  Future<List<Message>> fetchMessages(String chatId, {int limit = 50}) async {
    return (await fetchMessagePage(chatId, limit: limit)).messages;
  }

  Future<MessagePage> fetchMessagePage(
    String chatId, {
    int limit = 50,
    MessageCursor? before,
  }) async {
    assert(limit > 0);
    var query = _client
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .filter('deleted_at', 'is', null);
    if (before != null) {
      final timestamp = before.createdAt.toUtc().toIso8601String();
      query = query.or(
        'created_at.lt.$timestamp,and(created_at.eq.$timestamp,id.lt.${before.id})',
      );
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit + 1);
    final pageRows = (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final hasMore = pageRows.length > limit;
    if (hasMore) pageRows.removeLast();
    final messages = await _mapMessageRows(pageRows);
    final oldest = pageRows.lastOrNull;
    return MessagePage(
      messages: messages,
      hasMore: hasMore,
      nextCursor: oldest == null
          ? null
          : MessageCursor(
              createdAt: DateTime.parse(oldest['created_at'] as String),
              id: oldest['id'] as String,
            ),
    );
  }

  Future<List<Message>> _mapMessageRows(
    List<Map<String, dynamic>> pageRows,
  ) async {
    final pageIds = pageRows.map((row) => row['id'] as String).toSet();
    final missingReplyIds = pageRows
        .map((row) => row['reply_to'] as String?)
        .whereType<String>()
        .where((id) => !pageIds.contains(id))
        .toSet();
    var replyRows = <Map<String, dynamic>>[];
    if (missingReplyIds.isNotEmpty) {
      final extra = await _client
          .from('messages')
          .select()
          .inFilter('id', missingReplyIds.toList());
      replyRows = (extra as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    }
    final attachmentRows = await _fetchAttachmentsForMessages(
      <String>{
        ...pageRows.map((row) => row['id'] as String),
        ...replyRows.map((row) => row['id'] as String),
      }.toList(),
    );
    return messagesFromRows(
      pageRows.reversed,
      currentUserId: _uid,
      additionalReplyRows: replyRows,
      attachmentsByMessageId: attachmentRows,
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchAttachmentsForMessages(
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return const {};
    final rows = await _client
        .from('message_attachments')
        .select()
        .inFilter('message_id', messageIds);
    final attachments = (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final paths = attachments
        .where((row) => row['storage_bucket'] == 'message-media')
        .map((row) => row['storage_path'] as String)
        .toList();
    final signedUrls = paths.isEmpty
        ? const <SignedUrl>[]
        : await _client.storage
              .from('message-media')
              .createSignedUrls(paths, 60 * 60);
    final urlsByPath = {
      for (final signed in signedUrls) signed.path: signed.signedUrl,
    };
    final byMessage = <String, List<Map<String, dynamic>>>{};
    for (final row in attachments) {
      final path = row['storage_path'] as String;
      row['url'] = urlsByPath[path];
      final messageId = row['message_id'] as String;
      byMessage.putIfAbsent(messageId, () => []).add(row);
    }
    return byMessage;
  }

  /// Emits individual message changes rather than an ever-growing table
  /// snapshot. A resync marker is emitted after a channel reconnect so the
  /// caller can refresh only its bounded, currently loaded window.
  Stream<MessageChange> watchMessageChanges(String chatId) {
    late final RealtimeChannel channel;
    late final StreamController<MessageChange> controller;
    controller = StreamController<MessageChange>(
      onListen: () {
        channel = _client.channel(
          'messages:$chatId:${DateTime.now().microsecondsSinceEpoch}',
        );
        channel
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'chat_id',
                value: chatId,
              ),
              callback: (payload) {
                if (controller.isClosed) return;
                if (payload.eventType == PostgresChangeEvent.delete) {
                  controller.add(MessageChange.remove(payload.oldRecord));
                  return;
                }
                final row = payload.newRecord;
                if (row['deleted_at'] != null) {
                  controller.add(MessageChange.remove(row));
                } else {
                  controller.add(MessageChange.upsert(row));
                }
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'message_attachments',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'chat_id',
                value: chatId,
              ),
              callback: (_) {
                if (!controller.isClosed) {
                  controller.add(const MessageChange.resync());
                }
              },
            )
            .subscribe((status, [error]) {
              if (status != RealtimeSubscribeStatus.subscribed ||
                  controller.isClosed) {
                return;
              }
              // Also resync on the first subscription. This closes the small
              // gap between the initial page query and channel readiness;
              // later subscriptions use the same marker after reconnect.
              controller.add(const MessageChange.resync());
            });
      },
      onCancel: () async {
        await _client.removeChannel(channel);
      },
    );
    return controller.stream;
  }

  Future<Message?> messageFromRealtimeRow(Map<String, dynamic> row) async {
    if (row['deleted_at'] != null) return null;
    final messages = await _mapMessageRows([row]);
    return messages.firstOrNull;
  }

  Stream<List<Map<String, dynamic>>> watchReads(String chatId) {
    return _client
        .from('message_reads')
        .stream(primaryKey: ['message_id', 'user_id'])
        .eq('chat_id', chatId);
  }

  Future<({String id, DateTime createdAt})> sendMessage({
    required String chatId,
    required String body,
    String? clientMessageId,
    String? replyToId,
  }) async {
    final payload = {
      'id': ?clientMessageId,
      'chat_id': chatId,
      'sender_id': _uid,
      'body': body,
      'reply_to': ?replyToId,
    };
    Map<String, dynamic> row;
    try {
      row = await _client.from('messages').insert(payload).select().single();
    } on PostgrestException catch (error) {
      if (clientMessageId == null || error.code != '23505') rethrow;
      final existing = await _client
          .from('messages')
          .select('id,chat_id,sender_id,body,created_at,reply_to,deleted_at')
          .eq('id', clientMessageId)
          .maybeSingle();
      if (existing == null ||
          existing['chat_id'] != chatId ||
          existing['sender_id'] != _uid ||
          existing['body'] != body ||
          existing['reply_to'] != replyToId ||
          existing['deleted_at'] != null) {
        throw StateError('idempotency_conflict');
      }
      row = existing;
    }
    return (
      id: row['id'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  Future<({String id, DateTime createdAt, MessageAttachment attachment})>
  sendPhotoMessage({
    required String chatId,
    required PickedChatImage image,
    required String caption,
    String? clientMessageId,
    String? replyToId,
  }) async {
    final localId = clientMessageId ?? _newStorageSafeId();
    final extension = _extensionForMime(image.mimeType);
    final storagePath = '$chatId/$_uid/$localId.$extension';
    await _client.storage
        .from('message-media')
        .uploadBinary(
          storagePath,
          image.bytes,
          fileOptions: FileOptions(
            contentType: image.mimeType,
            cacheControl: '3600',
            upsert: true,
          ),
        );

    Map<String, dynamic> row;
    final payload = {
      'id': localId,
      'chat_id': chatId,
      'sender_id': _uid,
      'body': caption.trim(),
      'message_type': 'image',
      'reply_to': ?replyToId,
    };
    try {
      row = await _client.from('messages').insert(payload).select().single();
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      final existing = await _client
          .from('messages')
          .select(
            'id,chat_id,sender_id,body,message_type,created_at,reply_to,deleted_at',
          )
          .eq('id', localId)
          .maybeSingle();
      if (existing == null ||
          existing['chat_id'] != chatId ||
          existing['sender_id'] != _uid ||
          existing['body'] != caption.trim() ||
          existing['message_type'] != 'image' ||
          existing['reply_to'] != replyToId ||
          existing['deleted_at'] != null) {
        throw StateError('idempotency_conflict');
      }
      row = existing;
    }

    final attachmentPayload = {
      'message_id': row['id'],
      'chat_id': chatId,
      'storage_bucket': 'message-media',
      'storage_path': storagePath,
      'mime_type': image.mimeType,
      'byte_size': image.bytes.length,
    };
    Map<String, dynamic>? attachmentRow;
    try {
      attachmentRow = await _client
          .from('message_attachments')
          .insert(attachmentPayload)
          .select()
          .single();
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      attachmentRow = await _client
          .from('message_attachments')
          .select()
          .eq('message_id', row['id'] as String)
          .maybeSingle();
    }
    final url = await _client.storage
        .from('message-media')
        .createSignedUrl(storagePath, 60 * 60);
    final attachment = MessageAttachment(
      id: attachmentRow?['id'] as String? ?? row['id'] as String,
      messageId: row['id'] as String,
      chatId: chatId,
      storageBucket: 'message-media',
      storagePath: storagePath,
      mimeType: image.mimeType,
      byteSize: image.bytes.length,
      url: url,
    );
    return (
      id: row['id'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      attachment: attachment,
    );
  }

  Future<void> markRead({
    required String chatId,
    required List<String> messageIds,
    bool receiptVisible = true,
  }) async {
    if (messageIds.isEmpty) return;
    final rows = messageIds
        .map(
          (id) => {
            'message_id': id,
            'user_id': _uid,
            'chat_id': chatId,
            'receipt_visible': receiptVisible,
          },
        )
        .toList();
    // ON CONFLICT DO NOTHING — read receipts are insert-once. Using the
    // default upsert (DO UPDATE) hit the missing UPDATE policy on
    // message_reads and got rejected by RLS.
    await _client.from('message_reads').upsert(rows, ignoreDuplicates: true);
  }

  Future<void> editMessage({
    required String messageId,
    required String newBody,
  }) async {
    await _client
        .from('messages')
        .update({'body': newBody})
        .eq('id', messageId);
  }

  Future<void> softDelete(String messageId) async {
    await _client
        .from('messages')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', messageId);
  }

  /// Undo a soft-delete by nulling `deleted_at`. Paired with [softDelete] to
  /// implement the Undo SnackBar UX in the chat screen.
  Future<void> restoreMessage(String messageId) async {
    await _client
        .from('messages')
        .update({'deleted_at': null})
        .eq('id', messageId);
  }

  Future<List<Map<String, dynamic>>> fetchMessageReactions(
    String chatId,
  ) async {
    final rows = await _client
        .from('message_reactions')
        .select('message_id,user_id,emoji,created_at')
        .eq('chat_id', chatId)
        .order('created_at', ascending: true);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Stream<MessageReactionChange> watchMessageReactionChanges(String chatId) {
    late final RealtimeChannel channel;
    late final StreamController<MessageReactionChange> controller;
    controller = StreamController<MessageReactionChange>(
      onListen: () {
        channel = _client.channel(
          'message-reactions:$chatId:${DateTime.now().microsecondsSinceEpoch}',
        );
        channel
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'message_reactions',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'chat_id',
                value: chatId,
              ),
              callback: (payload) {
                if (controller.isClosed) return;
                if (payload.eventType == PostgresChangeEvent.delete) {
                  controller.add(
                    MessageReactionChange.remove(payload.oldRecord),
                  );
                  return;
                }
                controller.add(MessageReactionChange.upsert(payload.newRecord));
              },
            )
            .subscribe((status, [error]) {
              if (status != RealtimeSubscribeStatus.subscribed ||
                  controller.isClosed) {
                return;
              }
              controller.add(const MessageReactionChange.resync());
            });
      },
      onCancel: () async {
        await _client.removeChannel(channel);
      },
    );
    return controller.stream;
  }

  Future<void> upsertMessageReaction({
    required String chatId,
    required String messageId,
    required String emoji,
  }) async {
    // Insert-first, fall back to update on conflict. (A prior update-first
    // variant used `.update(...).select().maybeSingle()` to detect "no
    // existing row", but postgrest-dart's maybeSingle() only absorbs a
    // zero-row response for GET requests — for an UPDATE with zero matches
    // it throws PGRST116 instead of returning null, so every first-time
    // reaction failed silently.)
    try {
      await _client.from('message_reactions').insert({
        'message_id': messageId,
        'chat_id': chatId,
        'user_id': _uid,
        'emoji': emoji,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      await _client
          .from('message_reactions')
          .update({'emoji': emoji})
          .eq('message_id', messageId)
          .eq('user_id', _uid);
    }
  }

  Future<void> deleteMessageReaction({required String messageId}) async {
    await _client
        .from('message_reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', _uid);
  }

  /// Chat list rows for the current user from the chat_list view.
  /// Note: `chat_list` is a view — Supabase Realtime can't stream it directly.
  /// Use the one-shot fetcher [fetchChatList] in a polling loop tied to the
  /// source tables. Later tasks wire that up via Riverpod.
  Future<List<Map<String, dynamic>>> fetchChatList() async {
    final rows = await _client.from('chat_list').select().eq('viewer_id', _uid);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Source-table watchers used to invalidate the chat list cache.
  Stream<List<Map<String, dynamic>>> watchMyMemberships() {
    return _client
        .from('chat_members')
        .stream(primaryKey: ['chat_id', 'user_id'])
        .eq('user_id', _uid);
  }

  /// Emits when an authorized message insert, edit, or removal can change a
  /// chat-list preview. Postgres Changes applies message RLS before invoking
  /// the callback and does not send an initial message-history snapshot.
  Stream<void> watchChatListMessageChanges() {
    late final RealtimeChannel channel;
    late final StreamController<void> controller;
    controller = StreamController<void>(
      onListen: () {
        channel = _client.channel(
          'chat-list-messages:$_uid:${DateTime.now().microsecondsSinceEpoch}',
        );
        channel
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'messages',
              callback: (_) {
                if (!controller.isClosed) controller.add(null);
              },
            )
            .subscribe();
      },
      onCancel: () async {
        await _client.removeChannel(channel);
      },
    );
    return controller.stream;
  }

  Stream<void> watchChatListTranslationChanges() {
    late final RealtimeChannel channel;
    late final StreamController<void> controller;
    controller = StreamController<void>(
      onListen: () {
        channel = _client.channel(
          'chat-list-translations:$_uid:${DateTime.now().microsecondsSinceEpoch}',
        );
        channel
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'message_translations',
              callback: (_) {
                if (!controller.isClosed) controller.add(null);
              },
            )
            .subscribe();
      },
      onCancel: () async {
        await _client.removeChannel(channel);
      },
    );
    return controller.stream;
  }

  /// Persist a new learning language on the caller's chat_members row.
  /// PRD US-022 — picking a language in the ⋯ menu must survive cold
  /// start and any realtime refresh of `chat_list`.
  Future<void> setLearningLanguage({
    required String chatId,
    required String langCode,
  }) async {
    await _client
        .from('chat_members')
        .update({'learning_language': langCode})
        .eq('chat_id', chatId)
        .eq('user_id', _uid);
  }

  /// Fetch a cached translation for [messageId] into [targetLang], if
  /// any. Returns null on cache miss (so the caller falls back to the
  /// live translator).
  Future<CachedMessageTranslation?> fetchCachedTranslation({
    required String messageId,
    required String targetLang,
    required String interfaceLang,
  }) async {
    final row = await _client
        .from('message_translations')
        .select(
          'translation_text, interface_text, interface_lang, source_lang, aid_mode, '
          'explanation, confidence, tokens',
        )
        .eq('message_id', messageId)
        .eq('target_lang', targetLang)
        .eq('interface_lang', interfaceLang)
        .maybeSingle();
    if (row == null) return null;
    final rawTokens = row['tokens'];
    final tokens = <Map<String, dynamic>>[];
    if (rawTokens is List) {
      for (final t in rawTokens) {
        if (t is Map) tokens.add(Map<String, dynamic>.from(t));
      }
    }
    return (
      text: row['translation_text'] as String,
      interfaceText: row['interface_text'] as String,
      interfaceLang: row['interface_lang'] as String,
      sourceLang: row['source_lang'] as String,
      mode: row['aid_mode'] as String,
      explanation: row['explanation'] as String?,
      confidence: row['confidence'] as String?,
      tokens: tokens,
    );
  }

  MessageTranslationChange? _translationChangeFromRow(
    Map<String, dynamic> row,
  ) {
    final messageId = row['message_id'];
    final targetLang = row['target_lang'];
    final interfaceLang = row['interface_lang'];
    final text = row['translation_text'];
    final interfaceText = row['interface_text'];
    final sourceLang = row['source_lang'];
    final mode = row['aid_mode'];
    if (messageId is! String ||
        targetLang is! String ||
        interfaceLang is! String ||
        text is! String ||
        interfaceText is! String ||
        sourceLang is! String ||
        mode is! String) {
      return null;
    }
    final rawTokens = row['tokens'];
    final tokens = <Map<String, dynamic>>[];
    if (rawTokens is List) {
      for (final t in rawTokens) {
        if (t is Map) tokens.add(Map<String, dynamic>.from(t));
      }
    }
    return MessageTranslationChange(
      messageId: messageId,
      targetLang: targetLang,
      interfaceLang: interfaceLang,
      translation: (
        text: text,
        interfaceText: interfaceText,
        interfaceLang: interfaceLang,
        sourceLang: sourceLang,
        mode: mode,
        explanation: row['explanation'] as String?,
        confidence: row['confidence'] as String?,
        tokens: tokens,
      ),
    );
  }

  Stream<MessageTranslationChange> watchMessageTranslationChanges({
    required String targetLang,
    required String interfaceLang,
  }) {
    late final RealtimeChannel channel;
    late final StreamController<MessageTranslationChange> controller;
    controller = StreamController<MessageTranslationChange>(
      onListen: () {
        channel = _client.channel(
          'message-translations:$targetLang:$interfaceLang:${DateTime.now().microsecondsSinceEpoch}',
        );
        channel
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'message_translations',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'target_lang',
                value: targetLang,
              ),
              callback: (payload) {
                if (controller.isClosed ||
                    payload.eventType == PostgresChangeEvent.delete) {
                  return;
                }
                final change = _translationChangeFromRow(payload.newRecord);
                if (change == null || change.interfaceLang != interfaceLang) {
                  return;
                }
                controller.add(change);
              },
            )
            .subscribe();
      },
      onCancel: () async {
        await _client.removeChannel(channel);
      },
    );
    return controller.stream;
  }

  /// Bulk-fetch cached translations only for the currently loaded message
  /// ids. Returned as a map keyed by message id.
  Future<Map<String, CachedMessageTranslation>>
  fetchCachedTranslationsForMessages({
    required List<String> messageIds,
    required String targetLang,
    required String interfaceLang,
  }) async {
    if (messageIds.isEmpty) return {};
    final transRows = await _client
        .from('message_translations')
        .select(
          'message_id, translation_text, interface_text, interface_lang, source_lang, '
          'aid_mode, explanation, confidence, tokens',
        )
        .eq('target_lang', targetLang)
        .eq('interface_lang', interfaceLang)
        .inFilter('message_id', messageIds);
    final result = <String, CachedMessageTranslation>{};
    for (final row in transRows as List) {
      final id = row['message_id'] as String;
      final text = row['translation_text'] as String;
      final rawTokens = row['tokens'];
      final tokens = <Map<String, dynamic>>[];
      if (rawTokens is List) {
        for (final t in rawTokens) {
          if (t is Map) tokens.add(Map<String, dynamic>.from(t));
        }
      }
      result[id] = (
        text: text,
        interfaceText: row['interface_text'] as String,
        interfaceLang: row['interface_lang'] as String,
        sourceLang: row['source_lang'] as String,
        mode: row['aid_mode'] as String,
        explanation: row['explanation'] as String?,
        confidence: row['confidence'] as String?,
        tokens: tokens,
      );
    }
    return result;
  }

  // ---- Report + Block (Step 3.6a, Play UGC/CSAE policy) ----

  /// File an abuse report. Any of [reportedUserId] / [chatId] / [messageId]
  /// may be null depending on what's being reported.
  Future<String> reportContent({
    required String reason,
    String? reportedUserId,
    String? chatId,
    String? messageId,
    String? details,
  }) async {
    final reportId = await _client.rpc(
      'submit_report',
      params: {
        'p_reason': reason,
        'p_reported_user_id': reportedUserId,
        'p_chat_id': chatId,
        'p_message_id': messageId,
        'p_details': details,
      },
    );
    return reportId as String;
  }

  /// Block [userId] so they can no longer message the current user. The
  /// messages-insert RLS enforces this server-side. Idempotent.
  Future<void> blockUser(String userId) async {
    await _client
        .from('blocks')
        .upsert(
          {'blocker_id': _uid, 'blocked_id': userId},
          onConflict: 'blocker_id,blocked_id',
          ignoreDuplicates: true,
        );
  }

  /// Remove a block.
  Future<void> unblockUser(String userId) async {
    await _client
        .from('blocks')
        .delete()
        .eq('blocker_id', _uid)
        .eq('blocked_id', userId);
  }

  /// Ids the current user has blocked (one-shot).
  Future<Set<String>> fetchBlockedIds() async {
    final rows = await _client
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', _uid);
    return (rows as List).map((r) => r['blocked_id'] as String).toSet();
  }

  /// Realtime stream of the current user's blocked ids.
  Stream<Set<String>> watchBlockedIds() {
    return _client
        .from('blocks')
        .stream(primaryKey: ['blocker_id', 'blocked_id'])
        .eq('blocker_id', _uid)
        .map((rows) => rows.map((r) => r['blocked_id'] as String).toSet());
  }

  /// Server-side invite creation. The current user becomes the inviter
  /// and declares the language THEY want to learn from the partner the
  /// invite eventually claims. Returns the token + absolute expiry so
  /// the share sheet can build the `blab://invite/<token>` URL.
  Future<({String token, DateTime expiresAt})> createInvite({
    required String myLearningLanguage,
  }) async {
    final res = await _client.rpc(
      'create_invite',
      params: {'my_learning_language': myLearningLanguage},
    );
    final row = (res as List).first as Map<String, dynamic>;
    return (
      token: row['token'] as String,
      expiresAt: DateTime.parse(row['expires_at'] as String).toLocal(),
    );
  }

  /// Look up an invite for the landing screen. Returns null when the
  /// token isn't recognised (404). The RPC is callable by anon callers
  /// so the landing renders even before sign-in.
  Future<InviteMetadata?> getInvite(String token) async {
    final res = await _client.rpc(
      'get_invite',
      params: {'invite_token': token},
    );
    final rows = res as List;
    if (rows.isEmpty) return null;
    final row = rows.first as Map<String, dynamic>;
    return InviteMetadata(
      token: row['token'] as String,
      inviterUserId: row['inviter_user_id'] as String,
      inviterName: (row['inviter_name'] as String?) ?? '',
      inviterLearningLanguage:
          (row['inviter_learning_language'] as String?) ?? 'en',
      expiresAt: DateTime.parse(row['expires_at'] as String).toLocal(),
      status: row['status'] as String,
      resultingChatId: row['resulting_chat_id'] as String?,
      claimedByName: (row['claimed_by_name'] as String?)?.trim().isEmpty == true
          ? null
          : (row['claimed_by_name'] as String?),
    );
  }

  /// "Accept & join" path. Atomically marks the invite used, creates or
  /// reuses the pair's canonical chat, applies both selected learning
  /// languages, and returns that chat's id. Throws a [PostgrestException]
  /// with one of the documented
  /// `message` codes on failure: `invite_not_found`, `invite_expired`,
  /// `invite_already_claimed`, `invite_self_claim`, `not_signed_in`,
  /// `invalid_language`.
  Future<String> claimInvite({
    required String token,
    required String myLearningLanguage,
  }) async {
    final res = await _client.rpc(
      'claim_invite',
      params: {
        'invite_token': token,
        'my_learning_language': myLearningLanguage,
      },
    );
    final row = (res as List).first as Map<String, dynamic>;
    return row['chat_id'] as String;
  }
}
