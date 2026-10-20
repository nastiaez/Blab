import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/models/message_reaction.dart';

class MessageReactionBar extends StatelessWidget {
  const MessageReactionBar({
    super.key,
    required this.reactions,
    required this.isOutgoing,
    this.isPractice = false,
    required this.onTap,
  });

  final List<MessageReactionSummary> reactions;
  final bool isOutgoing;
  final bool isPractice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    // One reaction per participant: the sum is the number of people, not
    // a separate count badge for each emoji (BLA-21, owner14372).
    final people = reactions.fold<int>(
      0,
      (sum, reaction) => sum + reaction.count,
    );
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Container(
          key: const ValueKey('message-reaction-pill'),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF8),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFDCD2C8), width: 0.75),
            boxShadow: isPractice
                ? const [
                    BoxShadow(
                      color: Color(0x1A231208),
                      offset: Offset(0, 2),
                      blurRadius: 6,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < reactions.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Text(
                  reactions[i].emoji,
                  key: reactions[i].reactedByMe
                      ? ValueKey('my-reaction-${reactions[i].emoji}')
                      : null,
                  style: const TextStyle(fontSize: 16, height: 1),
                ),
              ],
              const SizedBox(width: 6),
              Text(
                '$people',
                key: const ValueKey('message-reaction-people-count'),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1,
                  color: BlabColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
