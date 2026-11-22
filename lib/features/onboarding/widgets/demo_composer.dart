import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../app/onboarding_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/blab_icon.dart';

/// Demonstration only: no focus node, editor, keyboard or remote actions.
class DemoComposer extends StatelessWidget {
  const DemoComposer({
    super.key,
    required this.draft,
    required this.translating,
    required this.pulse,
    required this.large,
  });
  final String draft;
  final bool translating, large;
  final double pulse;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final text = draft.isEmpty ? context.l10n.message : draft;
      final style = TextStyle(
        color: draft.isEmpty ? OnboardingTheme.muted : const Color(0xFF231208),
        fontSize: 14,
        height: 18 / 14,
      );
      // At large text, preserve full field width and stack the equally-sized circle
      // beneath it rather than forcing a narrow field/giant button feedback loop.
      final fieldWidth = large ? bounds.maxWidth : bounds.maxWidth - 48;
      final painter =
          TextPainter(
            text: TextSpan(text: text, style: style),
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: Directionality.of(context),
          )..layout(
            maxWidth: math.max(20, fieldWidth - 48 - (draft.isEmpty ? 20 : 0)),
          );
      final diameter = math.max(44.0, painter.height + 22);
      painter.dispose();
      final field = SizedBox(
        width: large ? fieldWidth : null,
        height: diameter,
        child: Container(
          key: const Key('demo1-composer'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF8),
            border: Border.all(color: const Color(0xFFE1DAD2)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const BlabIcon(
                name: 'emoji-face - 20',
                color: OnboardingTheme.warmInk,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Opacity(
                  opacity: translating ? pulse : 1,
                  child: Text(
                    text,
                    key: const Key('demo1-draft'),
                    style: style,
                  ),
                ),
              ),
              if (draft.isEmpty)
                const BlabIcon(
                  name: 'media-image - 20',
                  color: OnboardingTheme.warmInk,
                  size: 20,
                ),
            ],
          ),
        ),
      );
      final send = Container(
        key: const Key('demo1-send'),
        width: diameter,
        height: diameter,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: OnboardingTheme.action,
          shape: BoxShape.circle,
        ),
        child: BlabIcon(
          key: const Key('demo1-send-arrow'),
          name: 'chat-send-branded',
          color: const Color(0xFFFFFCF8),
          size: diameter * 0.62,
        ),
      );
      if (large) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [field, const SizedBox(height: 8), send],
        );
      }
      // Normal demo text fits one line at the canonical 306-unit phone width.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: field),
          const SizedBox(width: 4),
          send,
        ],
      );
    },
  );
}
