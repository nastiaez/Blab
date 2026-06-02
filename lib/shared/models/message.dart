import 'message_token.dart';

/// Delivery state for an outgoing message. Incoming messages are always
/// implicitly [delivered].
///
/// PRD US-016 (read receipts) + US-031 (offline / failure).
enum MessageStatus { pending, delivered, read, failed }

/// Render hint for a live-translated outgoing message in portfolio mode.
///
/// `null` (the default) means "no live translation flow involved" — the
/// existing rendering logic runs unchanged. [pending] tells the bubble to
/// show a shimmer in the subtitle slot while the translator is in flight.
/// [unavailable] tells it to show a muted "Translation unavailable" line.
/// On successful translation the field is reset to `null` so the message
/// renders like any normal outgoing bubble.
enum TranslationState { pending, unavailable }

/// A single chat message. Mock-only for Phase 1 — backend wiring lands in
/// Step 2.2.
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
    this.translationState,
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

  /// Optional translation render hint. See [TranslationState].
  final TranslationState? translationState;

  Message copyWith({
    MessageStatus? status,
    String? originalText,
    String? translation,
    List<MessageToken>? tokens,
    Message? replyTo,
    bool? isEdited,
    TranslationState? translationState,
    bool clearTranslationState = false,
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
      translationState: clearTranslationState
          ? null
          : (translationState ?? this.translationState),
    );
  }
}
