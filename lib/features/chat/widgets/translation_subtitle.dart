import 'package:flutter/material.dart';

import '../../../app/theme.dart';

enum TranslationSubtitleState { ready, pending, unavailable }

/// Renders the line that sits under a message bubble's main text. Owns the
/// thin divider above it. Used for both incoming and outgoing bubbles; the
/// caller picks the colors via [isOutgoing].
///
/// Pending state shows a single-line gradient shimmer (no extra package).
/// Unavailable state shows a muted italic "Translation unavailable" label.
class TranslationSubtitle extends StatelessWidget {
  const TranslationSubtitle({
    super.key,
    required this.state,
    required this.text,
    required this.isOutgoing,
  });

  final TranslationSubtitleState state;
  final String text;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    final divider = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        height: 1,
        color: isOutgoing
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.grey.shade200,
      ),
    );

    final Widget body;
    switch (state) {
      case TranslationSubtitleState.ready:
        body = Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: isOutgoing
                ? Colors.white.withValues(alpha: 0.85)
                : BlabColors.textMuted,
            height: 1.3,
          ),
        );
      case TranslationSubtitleState.pending:
        body = _ShimmerLine(isOutgoing: isOutgoing);
      case TranslationSubtitleState.unavailable:
        body = Text(
          'Translation unavailable',
          style: TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: isOutgoing
                ? Colors.white.withValues(alpha: 0.6)
                : BlabColors.textMuted,
            height: 1.3,
          ),
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [divider, body],
    );
  }
}

class _ShimmerLine extends StatefulWidget {
  const _ShimmerLine({required this.isOutgoing});
  final bool isOutgoing;

  @override
  State<_ShimmerLine> createState() => _ShimmerLineState();
}

class _ShimmerLineState extends State<_ShimmerLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.isOutgoing
        ? Colors.white.withValues(alpha: 0.25)
        : Colors.grey.shade200;
    final highlight = widget.isOutgoing
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.grey.shade100;
    return AnimatedBuilder(
      key: const ValueKey('translation-shimmer'),
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Container(
          height: 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(1 + 2 * t, 0),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
