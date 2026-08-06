import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/models/message_reaction.dart';

class MessageReactionBar extends StatelessWidget {
  const MessageReactionBar({
    super.key,
    required this.reactions,
    required this.isOutgoing,
    required this.onTap,
  });

  final List<MessageReactionSummary> reactions;
  final bool isOutgoing;
  final void Function(String emoji) onTap;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: isOutgoing ? WrapAlignment.end : WrapAlignment.start,
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final reaction in reactions)
          _ReactionChip(
            reaction: reaction,
            isOutgoing: isOutgoing,
            onTap: () => onTap(reaction.emoji),
          ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.reaction,
    required this.isOutgoing,
    required this.onTap,
  });

  final MessageReactionSummary reaction;
  final bool isOutgoing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mine = reaction.reactedByMe;
    final text = reaction.count > 1
        ? '${reaction.emoji} ${reaction.count}'
        : reaction.emoji;
    return InkWell(
      key: mine ? ValueKey('my-reaction-${reaction.emoji}') : null,
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: mine ? BlabColors.selectedTint : Colors.white,
          border: Border.all(
            color: mine
                ? BlabColors.brand.withValues(alpha: 0.55)
                : BlabColors.divider,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            height: 1,
            fontWeight: FontWeight.w600,
            color: BlabColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
