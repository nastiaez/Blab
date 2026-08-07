import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../message_actions.dart' show kQuickMessageReactions;

/// The compact horizontal emoji row that floats above a long-pressed
/// message bubble, Messenger-style. Packed closer together than the old
/// bottom-sheet picker; ends in a "+" that opens the full searchable sheet.
class FloatingReactionRow extends StatelessWidget {
  const FloatingReactionRow({
    super.key,
    required this.selectedEmoji,
    required this.onPick,
    required this.onMore,
  });

  /// The emoji the viewer has already reacted with on this message, if any.
  final String? selectedEmoji;
  final void Function(String emoji) onPick;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final emoji in kQuickMessageReactions)
              _EmojiButton(
                emoji: emoji,
                selected: emoji == selectedEmoji,
                onTap: () => onPick(emoji),
              ),
            _MoreButton(onTap: onMore),
          ],
        ),
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: selected ? const ValueKey('floating-reaction-selected') : null,
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? BlabColors.selectedTint : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 22, height: 1)),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('floating-reaction-more'),
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        alignment: Alignment.center,
        child: const Icon(Icons.add, size: 20, color: BlabColors.textMuted),
      ),
    );
  }
}
