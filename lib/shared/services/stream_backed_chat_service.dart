import '../models/message_mention.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import 'chat_service.dart';
import 'local_chat_history_cache.dart';
import 'stream_chat_session.dart';
import 'stream_message_transport.dart';

const streamReviewEnabled = bool.fromEnvironment('BLAB_STREAM_REVIEW');

ChatService createChatService(
  SupabaseClient client, {
  bool backgroundFetch = false,
}) => streamReviewEnabled && client.auth.currentUser != null
    ? StreamBackedChatService(client, backgroundFetch: backgroundFetch)
    : ChatService(client);

/// US-031: only explicitly activated review chats switch canonical transport.
class StreamBackedChatService extends ChatService {
  StreamBackedChatService(super.client, {bool backgroundFetch = false})
    : _supabase = client,
      _ownerId = client.auth.currentUser!.id,
      _session = StreamChatSession(client, backgroundFetch: backgroundFetch);
  final SupabaseClient _supabase;
  final String _ownerId;
  final StreamChatSession _session;
  late final _transport = StreamMessageTransport(_supabase, _session);
  final Map<String, Future<bool>> _routes = {};
  final Map<String, String> _messageChats = {};
  bool _disposed = false;

  void _checkIdentity() {
    if (_disposed || _supabase.auth.currentUser?.id != _ownerId) {
      throw StateError('account_changed');
    }
  }

  Future<bool> _isStream(String chatId) {
    _checkIdentity();
    final pending = _routes[chatId];
    if (pending != null) return pending;
    final lookup = () async {
      final row = await _supabase
          .from('chat_message_transports')
          .select('provider,migration_state')
          .eq('chat_id', chatId)
          .maybeSingle();
      _checkIdentity();
      return row?['provider'] == 'stream' &&
          row?['migration_state'] == 'active';
    }();
    _routes[chatId] = lookup;
    // Deduplicate in-flight reads, never retain a stale authority after cutover.
    return lookup.whenComplete(() {
      if (identical(_routes[chatId], lookup)) _routes.remove(chatId);
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    await _session.dispose();
  }

  Future<bool> usesStream(String chatId) => _isStream(chatId);

  Stream<Map<String, dynamic>> watchStreamTyping(String chatId) =>
      _transport.watchTyping(chatId);

  Future<void> sendStreamTyping(String chatId, bool value) =>
      _activity(chatId, value ? 'typing.start' : 'typing.stop');

  Future<void> _activity(
    String chatId,
    String action, {
    List<String> messageIds = const [],
    String? emoji,
  }) async {
    _checkIdentity();
    final response = await _supabase.functions.invoke(
      'stream-activity',
      body: {
        'chatId': chatId,
        'action': action,
        'messageIds': messageIds,
        'emoji': ?emoji,
      },
    );
    _checkIdentity();
    if (response.status != 200) throw StateError('stream_activity_unavailable');
  }

  @override
  Future<void> markRead({
    required String chatId,
    required List<String> messageIds,
    bool receiptVisible = true,
  }) async {
    // OFF returns before even opening/querying the transport.
    if (!receiptVisible || messageIds.isEmpty) return;
    if (!await _isStream(chatId)) {
      return super.markRead(
        chatId: chatId,
        messageIds: messageIds,
        receiptVisible: receiptVisible,
      );
    }
    for (var offset = 0; offset < messageIds.length; offset += 50) {
      await _activity(
        chatId,
        'read',
        messageIds: messageIds.skip(offset).take(50).toList(),
      );
    }
  }

  @override
  Future<void> upsertMessageReaction({
    required String chatId,
    required String messageId,
    required String emoji,
  }) async {
    if (!await _isStream(chatId)) {
      return super.upsertMessageReaction(
        chatId: chatId,
        messageId: messageId,
        emoji: emoji,
      );
    }
    await _activity(chatId, 'react', messageIds: [messageId], emoji: emoji);
  }

  @override
  Future<void> deleteMessageReaction({required String messageId}) async {
    final chatId = await _chatFor(messageId);
    if (!await _isStream(chatId)) {
      return super.deleteMessageReaction(messageId: messageId);
    }
    await _activity(chatId, 'unreact', messageIds: [messageId]);
  }

  @override
  Future<MessagePage> fetchMessagePage(
    String chatId, {
    int limit = 50,
    MessageCursor? before,
  }) async {
    if (!await _isStream(chatId)) {
      return super.fetchMessagePage(chatId, limit: limit, before: before);
    }
    final page = await _transport.fetchPage(
      chatId,
      limit: limit,
      before: before,
    );
    _checkIdentity();
    for (final message in page.messages) {
      _messageChats[message.id] = chatId;
    }
    final hydrated = await Future.wait(
      page.messages.map(_hydrateStreamMessage),
    );
    _checkIdentity();
    return MessagePage(
      messages: hydrated,
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
    );
  }

  @override
  Stream<MessageChange> watchMessageChanges(String chatId) async* {
    if (!await _isStream(chatId)) {
      yield* super.watchMessageChanges(chatId);
      return;
    }
    await for (final change in _transport.watchTimeline(chatId)) {
      _checkIdentity();
      final message = change.message;
      if (message != null) {
        _messageChats[message.id] = chatId;
        yield MessageChange.upsert({
          'id': message.id,
          'chat_id': chatId,
          '_stream_domain': message,
        });
      } else if (change.removedId != null) {
        yield MessageChange.remove({'id': change.removedId, 'chat_id': chatId});
      } else if (change.resync) {
        yield const MessageChange.resync();
      }
    }
  }

  @override
  Future<Message?> messageFromRealtimeRow(Map<String, dynamic> row) async {
    _checkIdentity();
    final domain = row['_stream_domain'];
    if (domain is Message) return _hydrateStreamMessage(domain);
    return super.messageFromRealtimeRow(row);
  }

  Future<Message> _hydrateStreamMessage(Message message) async {
    _checkIdentity();
    final reply = message.replyTo == null
        ? null
        : await _hydrateStreamMessage(message.replyTo!);
    final initialImage = message.attachment;
    if (initialImage == null) return message.copyWith(replyTo: reply);
    MessageAttachment image = initialImage;
    final cache = LocalChatHistoryCache(_ownerId);
    final bytes = await cache.loadAttachmentBytes(image.id);
    final preview = await cache.loadAttachmentPreviewBytes(image.id);
    _checkIdentity();
    if (image.storageBucket == 'stream-private-media' ||
        image.storageBucket == 'message-media') {
      try {
        final paths = {
          image.storagePath,
          image.previewStoragePath ?? image.storagePath,
        };
        if (paths.any(
          (path) =>
              !path.startsWith('${message.chatId}/') || path.contains('..'),
        )) {
          throw StateError('invalid_private_media');
        }
        final signed = await _supabase.storage
            .from(image.storageBucket)
            .createSignedUrls(paths.toList(), 60);
        _checkIdentity();
        final urls = {for (final item in signed) item.path: item.signedUrl};
        image = image.copyWith(
          url: urls[image.storagePath],
          previewUrl: urls[image.previewStoragePath ?? image.storagePath],
        );
      } catch (_) {
        /* Retain account-scoped cached bytes while offline. */
      }
    }
    if (preview == null && image.previewUrl != null) {
      unawaited(_warmStreamPreview(image.id, image.previewUrl!));
    }
    return message.copyWith(
      attachment: image.copyWith(localBytes: bytes, previewBytes: preview),
      replyTo: reply,
    );
  }

  Future<void> _warmStreamPreview(String id, String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      _checkIdentity();
      if (response.statusCode == 200 &&
          response.bodyBytes.length <= 10 * 1024 * 1024) {
        await LocalChatHistoryCache(
          _ownerId,
        ).saveAttachmentPreviewBytes(id, response.bodyBytes);
      }
    } catch (_) {
      /* An already cached preview remains useful offline. */
    }
  }

  Future<Map<String, dynamic>> _command({
    required String chatId,
    required String messageId,
    required String action,
    String? body,
    String? replyId,
    String? requestId,
    List<MessageMention> mentions = const [],
  }) async {
    _checkIdentity();
    final response = await _supabase.functions.invoke(
      'stream-message',
      body: {
        'chatId': chatId,
        'messageId': messageId,
        'action': action,
        'requestId': requestId ?? const Uuid().v4(),
        'body': ?body,
        if (action == 'send' || action == 'edit')
          'mentions': mentions.map((m) => m.toJson()).toList(),
        'replyId': ?replyId,
      },
    );
    _checkIdentity();
    final data = response.data;
    if (response.status != 200 ||
        data is! Map ||
        data['id'] != messageId ||
        data['createdAt'] is! String) {
      throw StateError('stream_message_unavailable');
    }
    _messageChats[messageId] = chatId;
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<({String id, DateTime createdAt})> sendMessage({
    required String chatId,
    required String body,
    String? clientMessageId,
    String? replyToId,
    List<MessageMention> mentions = const [],
  }) async {
    if (!await _isStream(chatId)) {
      return super.sendMessage(
        chatId: chatId,
        body: body,
        clientMessageId: clientMessageId,
        replyToId: replyToId,
        mentions: mentions,
      );
    }
    final id = clientMessageId ?? const Uuid().v4();
    final result = await _command(
      chatId: chatId,
      messageId: id,
      requestId: id,
      action: 'send',
      body: body,
      mentions: mentions,
      replyId: replyToId,
    );
    return (
      id: id,
      createdAt: DateTime.parse(result['createdAt'] as String).toLocal(),
    );
  }

  @override
  Future<({String id, DateTime createdAt, MessageAttachment attachment})>
  sendPhotoMessage({
    required String chatId,
    required PickedChatImage image,
    required String caption,
    String? clientMessageId,
    String? replyToId,
  }) async {
    if (!await _isStream(chatId)) {
      return super.sendPhotoMessage(
        chatId: chatId,
        image: image,
        caption: caption,
        clientMessageId: clientMessageId,
        replyToId: replyToId,
      );
    }
    _checkIdentity();
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) throw StateError('not_signed_in');
    final id = clientMessageId ?? const Uuid().v4();
    final preview = chatImagePreview(image);
    final uploaded = await _supabase.functions.invoke(
      'stream-media',
      headers: {'Authorization': 'Bearer $token'},
      body: <String, String>{'chatId': chatId, 'messageId': id},
      files: [
        http.MultipartFile.fromBytes(
          'original',
          image.bytes,
          filename: '$id.image',
          contentType: MediaType.parse(image.mimeType),
        ),
        if (image.mimeType != 'image/gif')
          http.MultipartFile.fromBytes(
            'preview',
            preview.bytes,
            filename: '$id.preview',
            contentType: MediaType.parse(preview.mimeType),
          ),
      ],
    );
    _checkIdentity();
    final raw = uploaded.data is Map
        ? (uploaded.data as Map)['attachment']
        : null;
    if (uploaded.status != 200 ||
        raw is! Map ||
        raw['blab_asset_id'] != id ||
        (raw['blab_storage_bucket'] != 'stream-private-media' &&
            raw['asset_url'] is! String)) {
      throw StateError('image_upload_unavailable');
    }
    final result = await _command(
      chatId: chatId,
      messageId: id,
      requestId: id,
      action: 'send_image',
      body: caption.trim(),
      replyId: replyToId,
    );
    final attachment = MessageAttachment(
      id: id,
      messageId: id,
      chatId: chatId,
      storageBucket: raw['blab_storage_bucket'] as String? ?? 'stream',
      storagePath: raw['blab_storage_path'] as String? ?? id,
      previewStoragePath: raw['blab_preview_storage_path'] as String?,
      mimeType: image.mimeType,
      byteSize: image.bytes.length,
      url: raw['asset_url'] as String?,
      previewUrl: raw['thumb_url'] as String?,
      previewMimeType: preview.mimeType,
      previewByteSize: preview.bytes.length,
      localBytes: image.bytes,
      previewBytes: preview.bytes,
    );
    final cache = LocalChatHistoryCache(_ownerId);
    await cache.saveAttachmentBytes(id, image.bytes);
    await cache.saveAttachmentPreviewBytes(id, preview.bytes);
    _checkIdentity();
    return (
      id: id,
      createdAt: DateTime.parse(result['createdAt'] as String).toLocal(),
      attachment: attachment,
    );
  }

  Future<String> _chatFor(String messageId) async {
    _checkIdentity();
    final known = _messageChats[messageId];
    if (known != null) return known;
    final row = await _supabase
        .from('messages')
        .select('chat_id')
        .eq('id', messageId)
        .single();
    _checkIdentity();
    return row['chat_id'] as String;
  }

  @override
  Future<void> editMessage({
    required String messageId,
    required String newBody,
    List<MessageMention> mentions = const [],
  }) async {
    final chatId = await _chatFor(messageId);
    if (!await _isStream(chatId)) {
      return super.editMessage(
        messageId: messageId,
        newBody: newBody,
        mentions: mentions,
      );
    }
    await _command(
      chatId: chatId,
      messageId: messageId,
      action: 'edit',
      body: newBody,
      mentions: mentions,
    );
  }

  @override
  Future<void> softDelete(String messageId) async {
    final chatId = await _chatFor(messageId);
    if (!await _isStream(chatId)) return super.softDelete(messageId);
    await _command(chatId: chatId, messageId: messageId, action: 'delete');
  }

  @override
  Future<void> restoreMessage(String messageId) async {
    final chatId = await _chatFor(messageId);
    if (!await _isStream(chatId)) return super.restoreMessage(messageId);
    await _command(chatId: chatId, messageId: messageId, action: 'restore');
  }
}
