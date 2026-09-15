import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_storage_keys.dart';
import '../data/languages.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../state/auth_state.dart';

/// Account-scoped, device-local recovery cache for the last known chat state.
/// Supabase remains authoritative; this store is only used to paint history
/// while offline or while a realtime reconnect is in flight (US-031, FR-41).
class LocalChatHistoryCache {
  LocalChatHistoryCache(this.userId);

  final String userId;

  // Keep opened full-resolution files useful across restarts without allowing
  // them to grow the app-private cache forever. Synced previews stay with the
  // cached chat history and are not part of this account-scoped LRU index.
  static const _maxAttachmentBytes = 20 * 1024 * 1024;
  static final Map<String, Future<void>> _fullAttachmentQueues = {};

  Future<List<int>?> loadAttachmentBytes(String attachmentId) {
    return _serializeFullAttachmentOperation(() async {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.get(
        cachedAttachmentStorageKey(userId: userId, attachmentId: attachmentId),
      );
      if (raw is! String || raw.isEmpty) return null;
      late final List<int> bytes;
      try {
        bytes = base64Decode(raw);
      } catch (_) {
        return null;
      }
      try {
        await _touchAttachment(attachmentId, bytes.length, prefs: prefs);
      } catch (_) {
        // Index repair is best-effort when valid photo bytes are already local.
      }
      return bytes;
    });
  }

  Future<List<int>?> loadAttachmentPreviewBytes(String attachmentId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.get(
      cachedAttachmentPreviewStorageKey(
        userId: userId,
        attachmentId: attachmentId,
      ),
    );
    return _safeBase64Decode(raw);
  }

  Future<void> saveAttachmentBytes(String attachmentId, List<int> bytes) async {
    if (bytes.isEmpty) return;
    await _serializeFullAttachmentOperation(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        cachedAttachmentStorageKey(userId: userId, attachmentId: attachmentId),
        base64Encode(bytes),
      );
      await _touchAttachment(attachmentId, bytes.length, prefs: prefs);
    });
  }

  Future<void> saveAttachmentPreviewBytes(
    String attachmentId,
    List<int> bytes,
  ) async {
    if (bytes.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      cachedAttachmentPreviewStorageKey(
        userId: userId,
        attachmentId: attachmentId,
      ),
      base64Encode(bytes),
    );
  }

  Future<void> saveChats(Iterable<Chat> chats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      cachedChatsStorageKey(userId),
      jsonEncode(chats.map(_chatToJson).toList()),
    );
  }

  Future<List<Chat>> loadChats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cachedChatsStorageKey(userId));
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((row) => _chatFromJson(Map<String, dynamic>.from(row)))
          .whereType<Chat>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveLanguageTimeline(
    String chatId,
    Iterable<Map<String, dynamic>> rows,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      cachedLanguageTimelineStorageKey(userId: userId, chatId: chatId),
      jsonEncode(rows.toList()),
    );
  }

  Future<List<Map<String, dynamic>>> loadLanguageTimeline(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      cachedLanguageTimelineStorageKey(userId: userId, chatId: chatId),
    );
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveMessages(String chatId, Iterable<Message> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = <Map<String, dynamic>>[];
    for (final message in messages) {
      serialized.add(_messageToJson(message));
      final attachment = message.attachment;
      final bytes = attachment?.localBytes;
      if (attachment != null && bytes != null && bytes.isNotEmpty) {
        await saveAttachmentBytes(attachment.id, bytes);
      }
      final previewBytes = attachment?.previewBytes;
      if (attachment != null &&
          previewBytes != null &&
          previewBytes.isNotEmpty) {
        await saveAttachmentPreviewBytes(attachment.id, previewBytes);
      }
    }
    await prefs.setString(
      cachedMessagesStorageKey(userId: userId, chatId: chatId),
      jsonEncode(serialized),
    );
  }

  Future<void> _touchAttachment(
    String attachmentId,
    int byteSize, {
    SharedPreferences? prefs,
  }) async {
    final preferences = prefs ?? await SharedPreferences.getInstance();
    final raw = preferences.get(cachedAttachmentIndexStorageKey(userId));
    final indexedEntries = <String, Map<String, dynamic>>{};
    var hasFullyValidIndex = raw is String;
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final value in decoded) {
            if (value is! Map) {
              hasFullyValidIndex = false;
              continue;
            }
            final id = value['id'];
            final size = value['size'];
            final usedAt = value['usedAt'];
            if (id is! String ||
                id.isEmpty ||
                id.startsWith('preview:') ||
                size is! num ||
                !size.isFinite ||
                size < 0 ||
                usedAt is! num ||
                !usedAt.isFinite) {
              hasFullyValidIndex = false;
              continue;
            }
            final existing = indexedEntries[id];
            if (existing != null) {
              hasFullyValidIndex = false;
              if ((existing['usedAt'] as num) >= usedAt) continue;
            }
            indexedEntries[id] = {'id': id, 'size': size, 'usedAt': usedAt};
          }
        } else {
          hasFullyValidIndex = false;
        }
      } catch (_) {
        hasFullyValidIndex = false;
        // A corrupt index is recoverable: the attachment values remain valid.
      }
    }
    final fullStoragePrefix = cachedAttachmentStorageKey(
      userId: userId,
      attachmentId: '',
    );
    final storageKeyById = <String, String>{};
    for (final key in preferences.getKeys()) {
      if (!key.startsWith(fullStoragePrefix)) continue;
      final id = key.substring(fullStoragePrefix.length);
      if (id.isEmpty) continue;
      storageKeyById[id] = key;
    }
    final storedIdsMatchIndex =
        storageKeyById.length == indexedEntries.length &&
        storageKeyById.keys.every(indexedEntries.containsKey);
    final entries = <Map<String, dynamic>>[];
    if (hasFullyValidIndex && storedIdsMatchIndex) {
      entries.addAll(indexedEntries.values.map(Map<String, dynamic>.from));
    } else {
      for (final entry in storageKeyById.entries) {
        final id = entry.key;
        if (id == attachmentId) continue;
        final indexed = hasFullyValidIndex ? indexedEntries[id] : null;
        if (indexed != null) {
          entries.add(Map<String, dynamic>.from(indexed));
          continue;
        }
        final stored = preferences.get(entry.value);
        if (stored is! String || stored.isEmpty) {
          await preferences.remove(entry.value);
          continue;
        }
        late final int decodedSize;
        try {
          decodedSize = base64Decode(stored).length;
        } catch (_) {
          await preferences.remove(entry.value);
          continue;
        }
        entries.add({
          'id': id,
          'size': decodedSize,
          'usedAt': indexedEntries[id]?['usedAt'] ?? 0,
        });
      }
    }
    entries.removeWhere((entry) => entry['id'] == attachmentId);
    entries.add({
      'id': attachmentId,
      'size': byteSize,
      'usedAt': DateTime.now().microsecondsSinceEpoch,
    });
    entries.sort((a, b) => (a['usedAt'] as num).compareTo(b['usedAt'] as num));
    var total = entries.fold<num>(
      0,
      (sum, entry) => sum + (entry['size'] as num),
    );
    // A single oversized file is not allowed to punch through the budget. It
    // is evicted as well, leaving the durable Supabase original untouched.
    while (entries.isNotEmpty && total > _maxAttachmentBytes) {
      final evicted = entries.removeAt(0);
      total -= evicted['size'] as num;
      final id = evicted['id'];
      if (id is String) {
        await preferences.remove(
          cachedAttachmentStorageKey(userId: userId, attachmentId: id),
        );
      }
    }
    await preferences.setString(
      cachedAttachmentIndexStorageKey(userId),
      jsonEncode(entries),
    );
  }

  Future<T> _serializeFullAttachmentOperation<T>(
    Future<T> Function() operation,
  ) {
    final previous = _fullAttachmentQueues[userId] ?? Future<void>.value();
    final result = previous.then<T>((_) => operation());
    final barrier = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _fullAttachmentQueues[userId] = barrier;
    return result.whenComplete(() {
      if (identical(_fullAttachmentQueues[userId], barrier)) {
        _fullAttachmentQueues.remove(userId);
      }
    });
  }

  Future<List<Message>> loadMessages(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      cachedMessagesStorageKey(userId: userId, chatId: chatId),
    );
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final messages = <Message>[];
      for (final value in decoded.whereType<Map>()) {
        final message = await _messageFromJson(
          prefs,
          userId,
          Map<String, dynamic>.from(value),
        );
        if (message != null) messages.add(message);
      }
      messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      return messages;
    } catch (_) {
      return const [];
    }
  }

  static Map<String, dynamic> _chatToJson(Chat chat) => {
    'id': chat.id,
    'partnerId': chat.partnerId,
    'partnerName': chat.partnerName,
    'learningLanguage': chat.learningLanguage.code,
    'mode': chat.mode.name,
    'partnerLearningLanguage': chat.partnerLearningLanguage.code,
    'translationCutoffAt': chat.translationCutoffAt?.toIso8601String(),
    'lastMessage': chat.lastMessage,
    'lastMessageTranslation': chat.lastMessageTranslation,
    'lastMessageId': chat.lastMessageId,
    'timestamp': chat.timestamp.toIso8601String(),
    'unreadCount': chat.unreadCount,
    'isNewInvite': chat.isNewInvite,
    'needsPracticeLanguageSelection': chat.needsPracticeLanguageSelection,
    'startedAt': chat.startedAt?.toIso8601String(),
  };

  static Chat? _chatFromJson(Map<String, dynamic> row) {
    final id = row['id'];
    final name = row['partnerName'];
    if (id is! String || name is! String) return null;
    BlabLanguage language(String? code) => kBlabLanguages.firstWhere(
      (entry) => entry.code == code,
      orElse: () => kBlabLanguages.firstWhere((entry) => entry.code == 'en'),
    );
    final learning = language(row['learningLanguage'] as String?);
    final partnerLearning = language(row['partnerLearningLanguage'] as String?);
    final timestamp = DateTime.tryParse(row['timestamp'] as String? ?? '');
    if (timestamp == null) return null;
    return Chat(
      id: id,
      partnerId: row['partnerId'] as String?,
      partnerName: name,
      partnerInitial: name.isEmpty ? '?' : name[0].toUpperCase(),
      learningLanguage: learning,
      mode: row['mode'] == 'normal' ? ChatMode.normal : ChatMode.practice,
      partnerNativeLanguage: learning,
      partnerLearningLanguage: partnerLearning,
      translationCutoffAt: DateTime.tryParse(
        row['translationCutoffAt'] as String? ?? '',
      ),
      lastMessage: row['lastMessage'] as String? ?? '',
      lastMessageTranslation: row['lastMessageTranslation'] as String? ?? '',
      lastMessageId: row['lastMessageId'] as String?,
      timestamp: timestamp,
      unreadCount: (row['unreadCount'] as num?)?.toInt() ?? 0,
      isNewInvite: row['isNewInvite'] as bool? ?? false,
      needsPracticeLanguageSelection:
          row['needsPracticeLanguageSelection'] as bool? ?? false,
      startedAt: DateTime.tryParse(row['startedAt'] as String? ?? ''),
    );
  }

  static Map<String, dynamic> _messageToJson(Message message) => {
    'id': message.id,
    'chatId': message.chatId,
    'isOutgoing': message.isOutgoing,
    'originalText': message.originalText,
    'sentAt': message.sentAt.toIso8601String(),
    'status': message.status.name,
    'type': message.type.name,
    'isEdited': message.isEdited,
    'attachment': message.attachment == null
        ? null
        : {
            'id': message.attachment!.id,
            'messageId': message.attachment!.messageId,
            'chatId': message.attachment!.chatId,
            'storageBucket': message.attachment!.storageBucket,
            'storagePath': message.attachment!.storagePath,
            'mimeType': message.attachment!.mimeType,
            'byteSize': message.attachment!.byteSize,
            'previewStoragePath': message.attachment!.previewStoragePath,
            'previewMimeType': message.attachment!.previewMimeType,
            'previewByteSize': message.attachment!.previewByteSize,
            'previewUrl': message.attachment!.previewUrl,
          },
    'replyTo': message.replyTo == null
        ? null
        : {
            'id': message.replyTo!.id,
            'chatId': message.replyTo!.chatId,
            'isOutgoing': message.replyTo!.isOutgoing,
            'originalText': message.replyTo!.originalText,
            'sentAt': message.replyTo!.sentAt.toIso8601String(),
            'type': message.replyTo!.type.name,
          },
  };

  static Future<Message?> _messageFromJson(
    SharedPreferences prefs,
    String userId,
    Map<String, dynamic> row,
  ) async {
    final id = row['id'];
    final chatId = row['chatId'];
    final originalText = row['originalText'];
    final sentAt = DateTime.tryParse(row['sentAt'] as String? ?? '');
    if (id is! String ||
        chatId is! String ||
        originalText is! String ||
        sentAt == null) {
      return null;
    }
    MessageAttachment? attachment;
    final rawAttachment = row['attachment'];
    if (rawAttachment is Map) {
      final data = Map<String, dynamic>.from(rawAttachment);
      final attachmentId = data['id'] as String?;
      if (attachmentId == null) return null;
      final rawBytes = prefs.get(
        cachedAttachmentStorageKey(userId: userId, attachmentId: attachmentId),
      );
      final rawPreviewBytes = prefs.get(
        cachedAttachmentPreviewStorageKey(
          userId: userId,
          attachmentId: attachmentId,
        ),
      );
      attachment = MessageAttachment(
        id: attachmentId,
        messageId: data['messageId'] as String? ?? id,
        chatId: data['chatId'] as String? ?? chatId,
        storageBucket: data['storageBucket'] as String? ?? 'message-media',
        storagePath: data['storagePath'] as String? ?? '',
        mimeType: data['mimeType'] as String? ?? 'image/jpeg',
        byteSize: (data['byteSize'] as num?)?.toInt() ?? 0,
        previewStoragePath: data['previewStoragePath'] as String?,
        previewMimeType: data['previewMimeType'] as String?,
        previewByteSize: (data['previewByteSize'] as num?)?.toInt(),
        previewUrl: data['previewUrl'] as String?,
        localBytes: _safeBase64Decode(rawBytes),
        previewBytes: _safeBase64Decode(rawPreviewBytes),
      );
    }
    final rawReply = row['replyTo'];
    Message? replyTo;
    if (rawReply is Map) {
      final reply = Map<String, dynamic>.from(rawReply);
      final replyTime = DateTime.tryParse(reply['sentAt'] as String? ?? '');
      if (reply['id'] is String && replyTime != null) {
        replyTo = Message(
          id: reply['id'] as String,
          chatId: reply['chatId'] as String? ?? chatId,
          isOutgoing: reply['isOutgoing'] as bool? ?? false,
          originalText: reply['originalText'] as String? ?? '',
          translation: '',
          sentAt: replyTime,
          status: MessageStatus.delivered,
          type: reply['type'] == 'image' ? MessageType.image : MessageType.text,
        );
      }
    }
    return Message(
      id: id,
      chatId: chatId,
      isOutgoing: row['isOutgoing'] as bool? ?? false,
      originalText: originalText,
      translation: '',
      sentAt: sentAt,
      status: MessageStatus.values.firstWhere(
        (value) => value.name == row['status'],
        orElse: () => MessageStatus.delivered,
      ),
      type: row['type'] == 'image' ? MessageType.image : MessageType.text,
      attachment: attachment,
      replyTo: replyTo,
      isEdited: row['isEdited'] as bool? ?? false,
    );
  }

  static List<int>? _safeBase64Decode(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }
}

final localChatHistoryCacheProvider = Provider<LocalChatHistoryCache?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return userId == null ? null : LocalChatHistoryCache(userId);
});
