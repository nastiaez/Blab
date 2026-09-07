import '../../../shared/models/message.dart';
import '../../../shared/models/chat.dart';

/// The action picked from the long-press action row. PRD US-019, US-020;
/// `report` added for Step 3.6a.
enum MessageAction { reply, edit, copy, original, listen, delete, report }

const Duration messageEditWindow = Duration(hours: 24);
const List<String> kQuickMessageReactions = [
  '❤️',
  '😂',
  '👍',
  '😮',
  '😢',
  '🙌',
];

bool hasSpeakableText(String text) =>
    RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(text);

bool canReplyToMessage(Message message) =>
    message.status == MessageStatus.delivered ||
    message.status == MessageStatus.read;

bool canEditMessage(Message message, {DateTime? now}) {
  if (!message.isOutgoing || !canReplyToMessage(message)) return false;
  final age = (now ?? DateTime.now()).toUtc().difference(
    message.sentAt.toUtc(),
  );
  return age <= messageEditWindow;
}

bool isPhotoOnlyMessage(Message message) =>
    message.attachment != null && message.originalText.trim().isEmpty;

List<MessageAction> actionsForMessage(
  Message message, {
  required ChatMode mode,
  required bool hasOriginal,
  required bool canListen,
  DateTime? now,
}) {
  final photoOnly = isPhotoOnlyMessage(message);
  return [
    if (canReplyToMessage(message)) MessageAction.reply,
    if (!photoOnly && canEditMessage(message, now: now)) MessageAction.edit,
    if (!photoOnly) MessageAction.copy,
    if (!photoOnly && mode == ChatMode.normal && hasOriginal)
      MessageAction.original,
    if (!photoOnly && mode == ChatMode.practice && canListen)
      MessageAction.listen,
    if (message.isOutgoing) MessageAction.delete else MessageAction.report,
  ];
}
