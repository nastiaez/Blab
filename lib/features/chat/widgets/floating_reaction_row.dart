import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/blab_icon.dart';
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
const Duration kFloatingReactionRowExitDuration = Duration(milliseconds: 150);
const Duration _containerEnterDuration = Duration(milliseconds: 250);
const Duration _itemTimelineDuration = Duration(milliseconds: 330);
const double _containerInitialScale = 0.88;
const double _itemInitialScale = 0.72;
const int _itemEnterDurationMs = 150;
const int _itemStaggerMs = 30;

/// The compact horizontal emoji row that floats above a long-pressed
/// message bubble, Messenger-style. Packed closer together than the old
/// bottom-sheet picker; ends in a "+" that opens the full searchable sheet.
class FloatingReactionRow extends StatefulWidget {
  const FloatingReactionRow({
    super.key,
    this.visible = true,
    this.scaleAlignment = Alignment.center,
    required this.selectedEmoji,
    required this.onPick,
    required this.onMore,
  });

  final bool visible;
  final Alignment scaleAlignment;

  /// The emoji the viewer has already reacted with on this message, if any.
  final String? selectedEmoji;
  final void Function(String emoji) onPick;
  final VoidCallback onMore;

  @override
  State<FloatingReactionRow> createState() => _FloatingReactionRowState();
}

class _FloatingReactionRowState extends State<FloatingReactionRow>
    with TickerProviderStateMixin {
  late final AnimationController _containerController;
  late final AnimationController _itemController;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _containerController = AnimationController(
      vsync: this,
      duration: _containerEnterDuration,
      reverseDuration: kFloatingReactionRowExitDuration,
    );
    _itemController = AnimationController(
      vsync: this,
      duration: _itemTimelineDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    _syncVisibility(restartEntrance: widget.visible);
  }

  @override
  void didUpdateWidget(covariant FloatingReactionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      _syncVisibility(restartEntrance: widget.visible);
    }
  }

  void _syncVisibility({required bool restartEntrance}) {
    if (_reduceMotion ?? false) {
      _containerController.value = widget.visible ? 1 : 0;
      _itemController.value = widget.visible ? 1 : 0;
      return;
    }

    if (widget.visible) {
      _containerController.forward(from: restartEntrance ? 0 : null);
      _itemController.forward(from: restartEntrance ? 0 : null);
    } else {
      _itemController.stop();
      _containerController.reverse();
    }
  }

  Animation<double> _itemScale(int index) {
    if ((_reduceMotion ?? false) || !widget.visible) {
      return const AlwaysStoppedAnimation(1);
    }
    final start =
        (index * _itemStaggerMs) / _itemTimelineDuration.inMilliseconds;
    final end =
        (index * _itemStaggerMs + _itemEnterDurationMs) /
        _itemTimelineDuration.inMilliseconds;
    return Tween<double>(begin: _itemInitialScale, end: 1).animate(
      CurvedAnimation(
        parent: _itemController,
        curve: Interval(start, end, curve: Curves.easeOutQuint),
      ),
    );
  }

  @override
  void dispose() {
    _containerController.dispose();
    _itemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = _reduceMotion ?? false;
    final containerScale = reducedMotion || !widget.visible
        ? const AlwaysStoppedAnimation<double>(1)
        : TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween<double>(
                begin: _containerInitialScale,
                end: 1.015,
              ).chain(CurveTween(curve: Curves.easeOutCubic)),
              weight: 75,
            ),
            TweenSequenceItem(
              tween: Tween<double>(
                begin: 1.015,
                end: 1,
              ).chain(CurveTween(curve: Curves.easeOutCubic)),
              weight: 25,
            ),
          ]).animate(_containerController);

    return IgnorePointer(
      ignoring: !widget.visible,
      child: FadeTransition(
        key: const ValueKey('floating-reaction-container-opacity'),
        opacity: _containerController,
        child: ScaleTransition(
          key: const ValueKey('floating-reaction-container-scale'),
          scale: containerScale,
          alignment: widget.scaleAlignment,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            elevation: 4,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            child: Padding(
              // Horizontal inset moved off this shared padding and onto the
              // outermost buttons' own margin below — same total row width,
              // but now every pixel of it belongs to a button's tap target.
              padding: const EdgeInsets.symmetric(vertical: _rowPaddingV),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (index, emoji) in kQuickMessageReactions.indexed)
                    ScaleTransition(
                      key: ValueKey('floating-reaction-item-$index'),
                      scale: _itemScale(index),
                      child: _EmojiButton(
                        emoji: emoji,
                        selected: emoji == widget.selectedEmoji,
                        onTap: () => widget.onPick(emoji),
                        extraLeadingMargin: index == 0 ? _rowPaddingH : 0,
                      ),
                    ),
                  ScaleTransition(
                    key: ValueKey(
                      'floating-reaction-item-${kQuickMessageReactions.length}',
                    ),
                    scale: _itemScale(kQuickMessageReactions.length),
                    child: _MoreButton(onTap: widget.onMore),
                  ),
                ],
              ),
            ),
          ),
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
          child: const BlabIcon(
            name: 'plus-circle - 20',
            size: 20,
            color: BlabColors.textMuted,
          ),
        ),
      ),
    );
  }
}
