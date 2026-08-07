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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: isOutgoing ? WrapAlignment.end : WrapAlignment.start,
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final reaction in reactions)
          _ReactionChip(reaction: reaction, isOutgoing: isOutgoing, onTap: onTap),
      ],
    );
  }
}

const double _kChipDiameter = 26;

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
    // Fill + border mirror the bubble it's attached to — a soft terracotta
    // tint for a message you sent, a soft blue-gray tint for one you
    // received. No separate "mine" treatment: which bubble a reaction sits
    // on already carries meaning, and a brand-colored ring would just show
    // as "always on" for whoever is testing solo.
    final fill = isOutgoing ? const Color(0xFFF7ECE7) : const Color(0xFFEAEFF2);
    final border = isOutgoing
        ? const Color(0xFFEFAF9D)
        : const Color(0xFFB4CFDA);
    return InkWell(
      key: reaction.reactedByMe
          ? ValueKey('my-reaction-${reaction.emoji}')
          : null,
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: _kChipDiameter,
            height: _kChipDiameter,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(color: border, width: 0.75),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              reaction.emoji,
              style: const TextStyle(fontSize: 14, height: 1),
            ),
          ),
          if (reaction.count > 1)
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: BlabColors.textPrimary,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Text(
                  '${reaction.count}',
                  style: const TextStyle(
                    fontSize: 9,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
