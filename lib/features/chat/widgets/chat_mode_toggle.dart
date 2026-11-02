import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/blab_icon.dart';

/// Shared dimensions for the approved content-fitting capsule.
double chatModeControlHeight(BuildContext context) =>
    math.max(48, MediaQuery.textScalerOf(context).scale(14) + 28);

double chatModeControlWidth(BuildContext context) {
  double measure(String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 14,
          height: 1,
          fontWeight: FontWeight.w600,
        ),
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width + 82;
  }

  return math.max(
    measure(context.l10n.normalMode),
    measure(context.l10n.practiceMode),
  );
}

/// One activation owner preserves the existing whole-control toggle grammar.
class BlabChatModeToggle extends StatelessWidget {
  const BlabChatModeToggle.segmented({
    super.key,
    required this.practice,
    required this.onChanged,
    this.compact = false,
  });
  final bool practice;
  final bool compact;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final activate = onChanged == null ? null : () => onChanged!(!practice);
    final visibleHeight = math.max(
      28.0,
      MediaQuery.textScalerOf(context).scale(14) + 8,
    );
    return Semantics(
      label: practice
          ? context.l10n.practiceModeTipTitle
          : context.l10n.normalModeTipTitle,
      toggled: practice,
      enabled: onChanged != null,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: activate,
          customBorder: const _CapsuleInkBorder(),
          splashFactory: NoSplash.splashFactory,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: chatModeControlHeight(context),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Container(
                key: const ValueKey('mode-toggle'),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  border: Border.all(color: BlabColors.chatDivider),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final isPractice in [false, true]) ...[
                        if (isPractice) const SizedBox(width: 2),
                        Container(
                          key: ValueKey(
                            'mode-toggle-segment-${isPractice ? 'flash - 16' : 'chat-bubble-empty - 16'}',
                          ),
                          constraints: BoxConstraints(
                            minWidth: 36,
                            minHeight: visibleHeight,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: practice == isPractice ? 8 : 0,
                          ),
                          decoration: BoxDecoration(
                            boxShadow: practice && isPractice
                                ? const [
                                    BoxShadow(
                                      color: Color(0x1A231208),
                                      offset: Offset(0, 2),
                                      blurRadius: 6,
                                      spreadRadius: -2,
                                    ),
                                  ]
                                : null,
                            color: practice == isPractice
                                ? (isPractice
                                      ? BlabColors.bubbleOutgoingPractice
                                      : const Color(0xFFCDC0B6))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              BlabIcon(
                                name: isPractice
                                    ? 'flash - 16'
                                    : 'chat-bubble-empty - 16',
                                color: practice == isPractice
                                    ? BlabColors.bubbleInk
                                    : const Color(0xFF8C735F),
                                size: 16,
                              ),
                              if (practice == isPractice && !compact) ...[
                                const SizedBox(width: 4),
                                Text(
                                  isPractice
                                      ? context.l10n.practiceMode
                                      : context.l10n.normalMode,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1,
                                    fontWeight: FontWeight.w600,
                                    color: BlabColors.bubbleInk,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
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

class _CapsuleInkBorder extends ShapeBorder {
  const _CapsuleInkBorder();
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override
  ShapeBorder scale(double t) => this;
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      const StadiumBorder().getOuterPath(
        Rect.fromLTRB(rect.left, rect.top + 7, rect.right, rect.bottom - 7),
        textDirection: textDirection,
      );
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}
}
