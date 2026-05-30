import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/models/chat.dart';
import '../../../shared/util/relative_time.dart';

class ChatListTile extends StatelessWidget {
  const ChatListTile({super.key, required this.chat, required this.onTap});

  final Chat chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _Avatar(initial: chat.partnerInitial),
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
                                chat.partnerName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: chat.unreadCount > 0
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: BlabColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(chat.learningLanguage.flag,
                                style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (chat.isNewInvite)
                        const _NewPill()
                      else
                        Text(
                          relativeTime(chat.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: chat.unreadCount > 0
                                ? BlabColors.brand
                                : BlabColors.textMuted,
                            fontWeight: chat.unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.w500,
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
                              ? 'New connection · say hi'
                              : chat.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: chat.unreadCount > 0
                                ? BlabColors.textPrimary
                                : BlabColors.textMuted,
                            fontWeight: chat.unreadCount > 0
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
  const _Avatar({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
      child: const Text(
        'New',
        style: TextStyle(
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
