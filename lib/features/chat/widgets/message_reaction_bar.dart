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
    return Wrap(
      alignment: isOutgoing ? WrapAlignment.end : WrapAlignment.start,
      // Each chip's tap target (_kHitDiameter) is wider than its visual
      // circle (_kChipDiameter), so a positive gap here reads as a much
      // bigger visual gap than it looks like it should. Negative spacing
      // pulls the invisible tap-target halos back into overlap, landing the
      // visible chips close together again; harmless since every chip on a
      // message shares the same onTap.
      spacing: -8,
      runSpacing: 4,
      children: [
        for (final reaction in reactions)
          _ReactionChip(
            reaction: reaction,
            isPractice: isPractice,
            onTap: onTap,
          ),
      ],
    );
  }
}

const double _kChipDiameter = 32;
// Tap target is bigger than the visual chip — 32px reads fine but is fiddly
// to hit precisely with a finger, so the invisible hit area extends past it
// toward Android's ~44-48dp minimum touch target.
const double _kHitDiameter = 44;

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.reaction,
    required this.isPractice,
    required this.onTap,
  });

  final MessageReactionSummary reaction;
  final bool isPractice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: reaction.reactedByMe
          ? ValueKey('my-reaction-${reaction.emoji}')
          : null,
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: _kHitDiameter,
        height: _kHitDiameter,
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: _kChipDiameter,
              height: _kChipDiameter,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF8),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFDCD2C8),
                  width: 0.75,
                ),
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
              child: Text(
                reaction.emoji,
                style: const TextStyle(fontSize: 16, height: 1),
              ),
            ),
            if (reaction.count > 1)
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
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
      ),
    );
  }
}
