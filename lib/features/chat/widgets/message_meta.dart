part of '../chat_screen.dart';

class MessageStatusNotice extends StatelessWidget {
  const MessageStatusNotice({
    super.key,
    required this.text,
    required this.onTap,
    required this.alignRight,
  });

  final String text;
  final VoidCallback? onTap;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Align(
      widthFactor: 1,
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            text,
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w500,
              color: BlabColors.error,
            ),
          ),
        ),
      ),
    );
  }
}

class UnsupportedLanguageNotice extends StatelessWidget {
  const UnsupportedLanguageNotice({
    super.key,
    required this.text,
    required this.alignRight,
  });

  final String text;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Align(
      widthFactor: 1,
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(
          text,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            fontSize: 12,
            height: 1.25,
            fontWeight: FontWeight.w400,
            color: Color(0xFF917869),
          ),
        ),
      ),
    );
  }
}

class MessageMeta extends StatelessWidget {
  const MessageMeta({
    super.key,
    required this.chatId,
    required this.message,
    required this.isOutgoing,
  });
  final String chatId;
  final Message message;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    final timeLabel = _formatTime(message.sentAt);
    final textColor = isOutgoing
        ? BlabColors.bubbleInk.withValues(alpha: 0.62)
        : BlabColors.textMuted;
    final children = <Widget>[
      Text(
        message.isEdited ? '${context.l10n.edited} · $timeLabel' : timeLabel,
        style: TextStyle(fontSize: 10, color: textColor),
      ),
    ];
    if (message.isOutgoing) {
      children.add(const SizedBox(width: 3));
      children.add(Text('·', style: TextStyle(fontSize: 10, color: textColor)));
      children.add(const SizedBox(width: 3));
      children.add(
        MessageDeliveryStatus(
          chatId: chatId,
          messageId: message.id,
          intrinsicStatus: message.status,
          isOutgoing: isOutgoing,
        ),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  static String _formatTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

final Map<String, _CachedAttachmentImage> _attachmentImageProviders =
    <String, _CachedAttachmentImage>{};
