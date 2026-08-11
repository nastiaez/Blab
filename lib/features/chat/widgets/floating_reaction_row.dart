import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../message_actions.dart' show kQuickMessageReactions;

/// Button metrics, kept next to the widgets that lay them out so the
/// positioning maths in chat_screen can't drift away from what actually
/// renders. Compact and packed on purpose — see the interaction spec.
const double _buttonSize = 36;
const double _buttonMargin = 1;
const double _rowPaddingH = 6;
const double _rowPaddingV = 4;

/// Rendered size of [FloatingReactionRow]. Six quick reactions plus the "+".
const double kFloatingReactionRowHeight = _buttonSize + (2 * _rowPaddingV);
final double kFloatingReactionRowWidth =
    (2 * _rowPaddingH) +
    (kQuickMessageReactions.length + 1) * (_buttonSize + 2 * _buttonMargin);

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
        // Horizontal inset moved off this shared padding and onto the
        // outermost buttons' own margin below — same total row width, but
        // now every pixel of it belongs to a button's tap target instead of
        // a chunk being dead Material background. Without that, the first
        // and last buttons had no neighbor to "catch" an overshoot toward
        // the row's edge (unlike the middle ones, where a miss still lands
        // on an adjacent button), so they read as unresponsive.
        padding: const EdgeInsets.symmetric(vertical: _rowPaddingV),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, emoji) in kQuickMessageReactions.indexed)
              _EmojiButton(
                emoji: emoji,
                selected: emoji == selectedEmoji,
                onTap: () => onPick(emoji),
                extraLeadingMargin: index == 0 ? _rowPaddingH : 0,
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
    this.extraLeadingMargin = 0,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;
  final double extraLeadingMargin;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: selected ? const ValueKey('floating-reaction-selected') : null,
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Semantics(
        label: 'React with $emoji',
        button: true,
        selected: selected,
        child: Container(
          width: _buttonSize,
          height: _buttonSize,
          margin: EdgeInsets.only(
            left: _buttonMargin + extraLeadingMargin,
            right: _buttonMargin,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? BlabColors.selectedTint : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: ExcludeSemantics(
            child: Text(emoji, style: const TextStyle(fontSize: 22, height: 1)),
          ),
        ),
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
      child: Semantics(
        label: 'More reactions',
        button: true,
        child: Container(
          width: _buttonSize,
          height: _buttonSize,
          margin: const EdgeInsets.only(
            left: _buttonMargin,
            right: _buttonMargin + _rowPaddingH,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.add, size: 20, color: BlabColors.textMuted),
        ),
      ),
    );
  }
}
