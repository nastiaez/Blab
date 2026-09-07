import 'message_token.dart';

/// Delivery state for an outgoing message. Incoming messages are always
/// implicitly [delivered].
///
/// PRD US-016 (read receipts) + US-031 (offline / failure).
enum MessageStatus { pending, delivered, read, failed }

enum MessageType { text, image }

class MessageAttachment {
  const MessageAttachment({
    required this.id,
    required this.messageId,
    required this.chatId,
    required this.storageBucket,
    required this.storagePath,
    required this.mimeType,
    required this.byteSize,
    this.previewStoragePath,
    this.previewMimeType,
    this.previewByteSize,
    this.previewUrl,
    this.previewBytes,
    this.url,
    this.localBytes,
  });

  final String id;
  final String messageId;
  final String chatId;
  final String storageBucket;
  final String storagePath;
  final String mimeType;
  final int byteSize;
  final String? previewStoragePath;
  final String? previewMimeType;
  final int? previewByteSize;
  final String? previewUrl;
  final List<int>? previewBytes;
  final String? url;
  final List<int>? localBytes;

  MessageAttachment copyWith({
    String? id,
    String? messageId,
    String? chatId,
    String? storageBucket,
    String? storagePath,
    String? mimeType,
    int? byteSize,
    String? previewStoragePath,
    String? previewMimeType,
    int? previewByteSize,
    String? previewUrl,
    List<int>? previewBytes,
    String? url,
    List<int>? localBytes,
  }) {
    return MessageAttachment(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      chatId: chatId ?? this.chatId,
      storageBucket: storageBucket ?? this.storageBucket,
      storagePath: storagePath ?? this.storagePath,
      mimeType: mimeType ?? this.mimeType,
      byteSize: byteSize ?? this.byteSize,
      previewStoragePath: previewStoragePath ?? this.previewStoragePath,
      previewMimeType: previewMimeType ?? this.previewMimeType,
      previewByteSize: previewByteSize ?? this.previewByteSize,
      previewUrl: previewUrl ?? this.previewUrl,
      previewBytes: previewBytes ?? this.previewBytes,
      url: url ?? this.url,
      localBytes: localBytes ?? this.localBytes,
    );
  }
}

/// A single chat message. Backed by the live Supabase stream (Step 2.2).
///
/// PRD US-013…US-017, US-023.
class Message {
  const Message({
    required this.id,
    required this.chatId,
    required this.isOutgoing,
    required this.originalText,
    required this.translation,
    required this.sentAt,
    required this.status,
    this.type = MessageType.text,
    this.attachment,
    this.tokens,
    this.replyTo,
    this.isEdited = false,
  });

  final String id;
  final String chatId;

  /// `true` if Nastia (the current user) sent this message; `false` if the
  /// partner sent it.
  final bool isOutgoing;

  /// Exact authored text. This is always the primary bubble content and is
  /// never replaced by either interface- or learning-language output.
  final String originalText;

  /// Legacy hydrated translation data. Live translations use the secure,
  /// locale-scoped message translation cache instead.
  final String translation;

  /// Optional per-word breakdown. Present on incoming target-language
  /// messages, `null` for plain outgoing English. Used by Step 1.6's
  /// word-popup.
  final List<MessageToken>? tokens;

  final DateTime sentAt;
  final MessageStatus status;
  final MessageType type;
  final MessageAttachment? attachment;

  /// The message this one replies to. Null when not a reply.
  final Message? replyTo;

  /// True when this message has been edited after sending. Renders a small
  /// "· edited" tag in the meta row. PRD US-019.
  final bool isEdited;

  Message copyWith({
    MessageStatus? status,
    String? originalText,
    String? translation,
    List<MessageToken>? tokens,
    MessageType? type,
    MessageAttachment? attachment,
    Message? replyTo,
    bool? isEdited,
  }) {
    return Message(
      id: id,
      chatId: chatId,
      isOutgoing: isOutgoing,
      originalText: originalText ?? this.originalText,
      translation: translation ?? this.translation,
      tokens: tokens ?? this.tokens,
      sentAt: sentAt,
      status: status ?? this.status,
      type: type ?? this.type,
      attachment: attachment ?? this.attachment,
      replyTo: replyTo ?? this.replyTo,
      isEdited: isEdited ?? this.isEdited,
    );
  }
}
