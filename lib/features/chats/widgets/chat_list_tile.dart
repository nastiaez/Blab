import '../../../shared/widgets/blab_unread_badge.dart';
import '../../../shared/widgets/blab_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../features/chat/state/typing_state.dart';
import '../../../shared/models/chat.dart';
import '../../../shared/util/relative_time.dart';

class ChatListTile extends ConsumerWidget {
  const ChatListTile({super.key, required this.chat, required this.onTap});

  final Chat chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasActualMessage = chat.lastMessageId != null;
    final partnerTyping =
        hasActualMessage &&
        !chat.isNewInvite &&
        (ref.watch(partnerTypingProvider(chat.id)).value ?? false);
    // A newly accepted connection carries the same visual weight as an
    // unread incoming message until this participant chooses a language.
    final hasUnread =
        chat.unreadCount > 0 || chat.needsPracticeLanguageSelection;
    final timestamp = relativeTime(chat.timestamp, context.l10n);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            BlabAvatar(name: chat.partnerName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.partnerName.isNotEmpty
                              ? chat.partnerName[0].toUpperCase() +
                                    chat.partnerName.substring(1)
                              : chat.partnerName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: BlabColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (hasActualMessage)
                        Text(
                          timestamp,
                          style: const TextStyle(
                            fontSize: 12,
                            color: BlabColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          !hasActualMessage
                              ? context.l10n.newConnectionSayHi
                              : partnerTyping
                              ? context.l10n.typing
                              : chat.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: partnerTyping
                                ? BlabColors.brand
                                : hasUnread
                                ? BlabColors.textPrimary
                                : BlabColors.textMuted,
                            fontWeight: partnerTyping || hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (hasActualMessage && chat.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        BlabUnreadBadge(count: chat.unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
