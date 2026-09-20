/// Always-visible Normal/Practice control for the chat header.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/models/chat.dart';
import '../../../shared/widgets/blab_icon.dart';
import '../state/chat_state.dart';
import 'word_popup.dart';

const double kNormalModeToggleWidth = 129;
const double kPracticeModeToggleWidth = 129;

class ModeToggle extends ConsumerWidget {
  const ModeToggle({
    super.key,
    required this.chatId,
    this.onBeforeToggle,
    this.onModeChanged,
  });

  final String chatId;
  final VoidCallback? onBeforeToggle;
  final ValueChanged<ChatMode>? onModeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(chatModeProvider(chatId));
    final practice = mode == ChatMode.practice;
    final hugNormalLabel =
        !practice && Localizations.localeOf(context).languageCode == 'uk';
    final minimumWidth = kNormalModeToggleWidth;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggle(context, ref),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minimumWidth,
          minHeight: 44,
          maxHeight: 44,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            key: const ValueKey('mode-toggle'),
            height: 34,
            constraints: BoxConstraints(minWidth: minimumWidth),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              border: Border.all(color: BlabColors.chatDivider),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Segment(
                  label: context.l10n.normalMode,
                  iconName: 'chat-bubble-empty - 16',
                  selected: !practice,
                  minimumWidth: !practice ? 83 : 36,
                  hugContent: hugNormalLabel,
                  onTap: () => _toggle(context, ref),
                ),
                const SizedBox(width: 2),
                _Segment(
                  label: context.l10n.practiceMode,
                  iconName: 'flash - 16',
                  selected: practice,
                  minimumWidth: 36,
                  hugContent: practice,
                  onTap: () => _toggle(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    onBeforeToggle?.call();
    final current = ref.read(chatModeProvider(chatId));
    final next = current == ChatMode.practice
        ? ChatMode.normal
        : ChatMode.practice;
    ref.read(chatModeResetSignalProvider(chatId).notifier).bump();
    dismissWordPopup();
    await ref.read(chatModeProvider(chatId).notifier).set(next);
    onModeChanged?.call(next);
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.iconName,
    required this.selected,
    required this.minimumWidth,
    required this.hugContent,
    required this.onTap,
  });

  final String label;
  final String iconName;
  final bool selected;
  final double minimumWidth;
  final bool hugContent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final segment = SizedBox(
      height: 44,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 28,
              constraints: BoxConstraints(minWidth: minimumWidth),
              padding: selected
                  ? const EdgeInsets.symmetric(horizontal: 8)
                  : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: selected
                    ? (iconName == 'flash - 16'
                          ? BlabColors.bubbleOutgoingPractice
                          : const Color(0xFFCDC0B6))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                boxShadow: selected && iconName == 'flash - 16'
                    ? [
                        const BoxShadow(
                          color: Color(0x1A231208),
                          offset: Offset(0, 2),
                          blurRadius: 6,
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: BlabIcon(
                      name: iconName,
                      color: selected
                          ? BlabColors.bubbleInk
                          : const Color(0xFF8C735F),
                      size: 16,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 4),
                    if (hugContent)
                      _SegmentLabel(label: label)
                    else
                      Flexible(child: _SegmentLabel(label: label)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label: label,
      button: true,
      selected: selected,
      onTap: onTap,
      child: SizedBox(
        key: ValueKey('mode-toggle-segment-$iconName'),
        width: hugContent ? null : minimumWidth,
        child: segment,
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w600,
          color: BlabColors.bubbleInk,
        ),
      ),
    );
  }
}
