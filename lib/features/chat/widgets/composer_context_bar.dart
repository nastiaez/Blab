part of '../chat_screen.dart';

class ComposerReplyBar extends StatelessWidget {
  const ComposerReplyBar({
    super.key,
    required this.message,
    required this.partnerName,
    required this.onClose,
  });

  final Message message;
  final String partnerName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final whose = message.isOutgoing ? context.l10n.you : partnerName;
    final accent = message.isOutgoing
        ? BlabColors.brand
        : BlabColors.avatarColorFor(partnerName);
    final attachment = message.attachment;
    final previewText =
        message.originalText.trim().isEmpty && attachment != null
        ? context.l10n.photoMessagePreview
        : message.originalText;
    return Container(
      decoration: const BoxDecoration(
        color: BlabColors.chatSurface,
        border: Border(top: BorderSide(color: BlabColors.chatDivider)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 12, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 3,
              height: 38,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 9),
            if (attachment != null) ...[
              ReplyThumbnail(attachment: attachment),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    whose,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    previewText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: BlabColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              child: Center(
                child: BlabIconButton(
                  onPressed: onClose,
                  tooltip: context.l10n.dismiss,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: BlabColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── edit bar ────────────────────────────────────────

/// Centered exchange card shown in any chat with no messages yet.
/// PRD US-027.
class ComposerEditBar extends StatelessWidget {
  const ComposerEditBar({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BlabColors.chatSurface,
      padding: const EdgeInsets.fromLTRB(14, 8, 12, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.editingMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: BlabColors.brand,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              child: Center(
                child: BlabIconButton(
                  onPressed: onClose,
                  tooltip: context.l10n.dismiss,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: BlabColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
