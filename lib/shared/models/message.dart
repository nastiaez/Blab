import 'message_token.dart';

/// Delivery state for an outgoing message. Incoming messages are always
/// implicitly [delivered].
///
/// PRD US-016 (read receipts) + US-031 (offline / failure).
enum MessageStatus { pending, delivered, read, failed }

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
    this.tokens,
    this.replyTo,
    this.isEdited = false,
  });

  final String id;
  final String chatId;

  /// `true` if Nastia (the current user) sent this message; `false` if the
  /// partner sent it.
  final bool isOutgoing;

  /// The text in the language it was typed in. For incoming messages this is
  /// usually the target language; for outgoing it's whichever language the
  /// user typed.
  final String originalText;

  /// The interface-language gloss shown below incoming bubbles. For outgoing
  /// messages this is generally an empty string (we don't translate the user
  /// to themselves in v1).
  final String translation;

  /// Optional per-word breakdown. Present on incoming target-language
  /// messages, `null` for plain outgoing English. Used by Step 1.6's
  /// word-popup.
  final List<MessageToken>? tokens;

  final DateTime sentAt;
  final MessageStatus status;

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
      replyTo: replyTo ?? this.replyTo,
      isEdited: isEdited ?? this.isEdited,
    );
  }
}
