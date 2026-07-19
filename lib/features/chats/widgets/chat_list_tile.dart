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
    final partnerTyping =
        !chat.isNewInvite &&
        (ref.watch(partnerTypingProvider(chat.id)).value ?? false);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _Avatar(name: chat.partnerName, initial: chat.partnerInitial),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
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
                            const SizedBox(width: 6),
                            Text(
                              chat.learningLanguage.flag,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (chat.isNewInvite)
                        const _NewPill()
                      else
                        Text(
                          relativeTime(chat.timestamp) == 'Now'
                              ? context.l10n.now
                              : relativeTime(chat.timestamp),
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
                          chat.isNewInvite
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
                                : chat.unreadCount > 0
                                ? BlabColors.textPrimary
                                : BlabColors.textMuted,
                            fontWeight: partnerTyping || chat.unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (!chat.isNewInvite && chat.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        _UnreadBadge(count: chat.unreadCount),
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.initial});
  final String name;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: BlabColors.avatarColorFor(name),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _NewPill extends StatelessWidget {
  const _NewPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: BlabColors.brand,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        context.l10n.newLabel,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        color: BlabColors.brand,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
