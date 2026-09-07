import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/models/message_token.dart';
import '../../../shared/widgets/blab_icon.dart';
import 'message_text.dart';

enum TranslationSubtitleState { ready, pending, unavailable }

/// Renders the learning-language aid alongside the exact authored message.
/// Owns the separating divider and keeps learning words tappable when token
/// metadata is available.
///
/// Pending state shows a single-line gradient shimmer (no extra package).
/// Unavailable state shows a muted italic "Translation unavailable" label.
class TranslationSubtitle extends StatelessWidget {
  const TranslationSubtitle({
    super.key,
    required this.state,
    required this.text,
    required this.isOutgoing,
    this.tokens,
    this.languageCode,
    this.popupTopInset = 0,
    this.unavailableText = 'Translation unavailable',
    this.retryText = 'Retry',
    this.onRetry,
    this.label,
    this.supportingText,
    this.dividerAfter = false,
  });

  final TranslationSubtitleState state;
  final String text;
  final bool isOutgoing;
  final List<MessageToken>? tokens;
  final String? languageCode;
  final double popupTopInset;
  final String unavailableText;
  final String retryText;
  final VoidCallback? onRetry;
  final String? label;
  final String? supportingText;
  final bool dividerAfter;

  @override
  Widget build(BuildContext context) {
    final divider = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        height: 1,
        color: isOutgoing
            ? BlabColors.bubbleInk.withValues(alpha: 0.22)
            : Colors.grey.shade200,
      ),
    );

    final Widget body;
    switch (state) {
      case TranslationSubtitleState.ready:
        final style = TextStyle(
          fontSize: 14,
          color: isOutgoing
              ? BlabColors.bubbleInk.withValues(alpha: 0.78)
              : BlabColors.textMuted,
          height: 1.3,
        );
        final message = languageCode == null
            ? Text(text, style: style)
            : MessageText(
                text: text,
                tokens: tokens,
                languageCode: languageCode!,
                popupTopInset: popupTopInset,
                style: style,
              );
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != null) ...[
              Text(
                label!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isOutgoing
                      ? BlabColors.bubbleInk.withValues(alpha: 0.68)
                      : BlabColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
            ],
            message,
            if (supportingText != null) ...[
              const SizedBox(height: 4),
              Text(
                supportingText!,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isOutgoing
                      ? BlabColors.bubbleInk.withValues(alpha: 0.68)
                      : BlabColors.textMuted,
                  height: 1.3,
                ),
              ),
            ],
          ],
        );
      case TranslationSubtitleState.pending:
        body = ShimmerLine(isOutgoing: isOutgoing);
      case TranslationSubtitleState.unavailable:
        final color = isOutgoing
            ? BlabColors.bubbleInk.withValues(alpha: 0.74)
            : BlabColors.textMuted;
        body = Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 2,
          children: [
            Text(
              unavailableText,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: color,
                height: 1.3,
              ),
            ),
            if (onRetry != null)
              TextButton.icon(
                key: const ValueKey('translation-retry'),
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: BlabIcon(
                  key: const ValueKey('translation-retry-icon'),
                  name: 'refresh - 16',
                  color: color,
                  size: 16,
                ),
                label: Text(
                  retryText,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [if (!dividerAfter) divider, body, if (dividerAfter) divider],
    );
  }
}

class ShimmerLine extends StatefulWidget {
  const ShimmerLine({super.key, required this.isOutgoing, this.height = 14});
  final bool isOutgoing;
  final double height;

  @override
  State<ShimmerLine> createState() => _ShimmerLineState();
}

class _ShimmerLineState extends State<ShimmerLine>
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
        ? BlabColors.bubbleInk.withValues(alpha: 0.18)
        : Colors.grey.shade200;
    final highlight = widget.isOutgoing
        ? BlabColors.bubbleInk.withValues(alpha: 0.34)
        : Colors.grey.shade100;
    return AnimatedBuilder(
      key: const ValueKey('translation-shimmer'),
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Container(
          height: widget.height,
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
