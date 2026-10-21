part of '../chat_screen.dart';

class ReplyPreview extends StatelessWidget {
  const ReplyPreview({
    super.key,
    required this.replyTo,
    required this.onTap,
    required this.partnerName,
    required this.parentIsOutgoing,
    required this.translation,
    required this.mode,
    required this.knownLanguageCodes,
    required this.targetLanguageCode,
    required this.readingScript,
  });

  final Message replyTo;
  final VoidCallback onTap;
  final String partnerName;
  final bool parentIsOutgoing;
  final AsyncValue<MessageTranslation>? translation;

  /// FR-23 / modes-known-languages spec: this preview follows the same
  /// three display rules as [MessageLearningContent] via
  /// [resolveMessageDisplayText] — a second message-rendering path that
  /// Task 9's rewrite didn't reach, fixed here rather than duplicated.
  final ChatMode mode;
  final List<String> knownLanguageCodes;
  final String targetLanguageCode;
  final ReadingScript readingScript;

  @override
  Widget build(BuildContext context) {
    final tintBg = replyTo.isOutgoing
        ? const Color(0xFFFAB894)
        : const Color(0xFFF5F0E8);
    final barColor = replyTo.isOutgoing
        ? BlabColors.brand
        : BlabColors.avatarColorFor(partnerName);
    final labelColor = barColor;
    final previewColor = parentIsOutgoing
        ? BlabColors.bubbleInk.withValues(alpha: 0.78)
        : BlabColors.textMuted;

    final author = replyTo.isOutgoing
        ? context.l10n.you
        : (replyTo.senderName ?? partnerName);
    final rawPreviewText = switch (translation) {
      AsyncData<MessageTranslation>(value: final value) =>
        resolveMessageDisplayText(
          authoredText: replyTo.originalText,
          value: value,
          mode: mode,
          knownLanguageCodes: knownLanguageCodes,
          targetLanguageCode: targetLanguageCode,
          readingScript: readingScript,
        ),
      _ => replyTo.originalText,
    };
    final previewText =
        rawPreviewText.trim().isEmpty && replyTo.attachment != null
        ? context.l10n.photoMessagePreview
        : rawPreviewText;
    final attachment = replyTo.attachment;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(color: tintBg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 4, height: 44, color: barColor),
              const SizedBox(width: 8),
              if (attachment != null) ...[
                ReplyThumbnail(attachment: attachment),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 5, 8, 5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        previewText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: previewColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReplyThumbnail extends StatelessWidget {
  const ReplyThumbnail({super.key, required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final provider = _attachmentImageProvider(attachment);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 36,
        height: 36,
        child: provider == null
            ? Container(color: Colors.black.withValues(alpha: 0.08))
            : Image(image: provider, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    );
  }
}

// ─────────────────────────── reply bar ───────────────────────────────────────
