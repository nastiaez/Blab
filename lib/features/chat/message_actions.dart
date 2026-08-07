import '../../../shared/models/message.dart';

/// The action picked from the long-press action row. PRD US-019, US-020;
/// `report` added for Step 3.6a.
enum MessageAction { reply, edit, copy, delete, report }

const Duration messageEditWindow = Duration(hours: 24);
const List<String> kQuickMessageReactions = [
  '❤️',
  '😂',
  '👍',
  '😮',
  '😢',
  '🙌',
];

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
