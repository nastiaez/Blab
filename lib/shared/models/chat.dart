import '../data/languages.dart';

class Chat {
  const Chat({
    required this.id,
    required this.partnerName,
    required this.partnerInitial,
    required this.learningLanguage,
    required this.partnerNativeLanguage,
    required this.partnerLearningLanguage,
    required this.lastMessage,
    required this.lastMessageTranslation,
    required this.timestamp,
    required this.unreadCount,
    this.lastMessageId,
    this.isNewInvite = false,
    this.startedAt,
    this.partnerId,
  });

  final String id;

  /// The partner's user id. Needed to block / report them. Null for mock
  /// chats that predate the chat-list view exposing it.
  final String? partnerId;

  final String partnerName;
  final String partnerInitial;

  /// What the local user is learning from the partner (= partner's native).
  final BlabLanguage learningLanguage;

  /// Partner's native language (what they teach you).
  final BlabLanguage partnerNativeLanguage;

  /// What the partner is currently learning from the local user.
  final BlabLanguage partnerLearningLanguage;

  final String lastMessage;
  final String lastMessageTranslation;

  /// Id of the most recent non-deleted message in the chat, or null if
  /// the chat has no messages yet. Used by the chat list tile to render
  /// the preview in the viewer's learning language via the live
  /// translation cache.
  final String? lastMessageId;
  final DateTime timestamp;
  final int unreadCount;
  final bool isNewInvite;

  /// When this chat was first started. Used for the "Started X ago" line on
  /// the partner profile sheet. Falls back to [timestamp] when null.
  final DateTime? startedAt;
}
