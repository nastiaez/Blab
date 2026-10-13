part of '../chat_screen.dart';

class MessageDeliveryStatus extends ConsumerWidget {
  const MessageDeliveryStatus({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.intrinsicStatus,
    required this.isOutgoing,
  });

  final String chatId;
  final String messageId;
  final MessageStatus intrinsicStatus;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Derive the displayed status from a combination of the message's own
    // state (pending / failed take precedence) and whether the partner has
    // read this message yet. Step 2.2 Task 10 / PRD US-016.
    MessageStatus status = intrinsicStatus;
    if (status == MessageStatus.delivered) {
      final readsAsync = ref.watch(readsForChatProvider(chatId));
      final reads = readsAsync.maybeWhen(
        data: (s) => s,
        orElse: () => const <String>{},
      );
      if (reads.contains(messageId)) {
        status = MessageStatus.read;
      }
    }

    // Semantics labels paired with the icon — read receipts and online
    // indicators must not be color-only. PRD US-033.
    final tint = BlabColors.bubbleInk.withValues(alpha: 0.5);
    switch (status) {
      case MessageStatus.pending:
        return Semantics(
          label: context.l10n.sending,
          child: Icon(
            Icons.access_time,
            size: 16,
            color: isOutgoing ? tint : BlabColors.textMuted,
          ),
        );
      case MessageStatus.delivered:
        return Semantics(
          label: context.l10n.delivered,
          child: BlabIcon(
            name: 'check - 16',
            size: 16,
            color: isOutgoing ? tint : Colors.grey.shade500,
          ),
        );
      case MessageStatus.read:
        return Semantics(
          label: context.l10n.read,
          child: BlabIcon(
            name: 'double-check - 16',
            size: 16,
            color: isOutgoing ? tint : Colors.grey.shade500,
          ),
        );
      case MessageStatus.failed:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────── input ───────────────────────────────────────────
