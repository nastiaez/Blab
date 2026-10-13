import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/blab_icon.dart';

/// Owner-requested custom segmented variant. Material owns focus/activation;
/// the appearance is Blab's exact original capsule, not a hidden Switch replica.
class BlabChatModeToggle extends StatelessWidget {
  const BlabChatModeToggle.segmented({
    super.key,
    required this.practice,
    required this.onChanged,
  });
  final bool practice;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    final hugNormal =
        !practice &&
        (Localizations.localeOf(context).languageCode == 'uk' || largeText);
    final activate = onChanged == null ? null : () => onChanged!(!practice);
    return Semantics(
      label: practice
          ? context.l10n.practiceModeTipTitle
          : context.l10n.normalModeTipTitle,
      toggled: practice,
      enabled: onChanged != null,
      button: true,
      onTap: activate,
      child: ExcludeSemantics(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            excludeFromSemantics: true,
            onTap: activate,
            borderRadius: BorderRadius.circular(17),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 129,
                minHeight: 44,
                maxHeight: 44,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  key: const ValueKey('mode-toggle'),
                  height: 34,
                  constraints: const BoxConstraints(minWidth: 129),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(color: BlabColors.chatDivider),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CapsuleSegment(
                        label: context.l10n.normalMode,
                        iconName: 'chat-bubble-empty - 16',
                        selected: !practice,
                        minimumWidth: !practice ? 83 : 36,
                        hugContent: hugNormal,
                      ),
                      const SizedBox(width: 2),
                      _CapsuleSegment(
                        label: context.l10n.practiceMode,
                        iconName: 'flash - 16',
                        selected: practice,
                        minimumWidth: 36,
                        hugContent: practice,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CapsuleSegment extends StatelessWidget {
  const _CapsuleSegment({
    required this.label,
    required this.iconName,
    required this.selected,
    required this.minimumWidth,
    required this.hugContent,
  });

  final String label;
  final String iconName;
  final bool selected;
  final double minimumWidth;
  final bool hugContent;

  @override
  Widget build(BuildContext context) {
    final segment = SizedBox(
      height: 44,
      child: Center(
        child: Material(
          color: Colors.transparent,
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
    );

    return SizedBox(
      key: ValueKey('mode-toggle-segment-$iconName'),
      width: hugContent ? null : minimumWidth,
      child: segment,
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
