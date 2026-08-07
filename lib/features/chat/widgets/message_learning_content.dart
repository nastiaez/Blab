import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/services/message_translator.dart';
import 'inline_correction_text.dart';
import 'message_text.dart';
import 'translation_subtitle.dart';

const double kTranslatedMessageMinContentWidth = 156;

/// Renders the final L-15 two-lane message contract: learning language on top
/// and interface language below, with a third-language author exception.
class MessageLearningContent extends StatelessWidget {
  const MessageLearningContent({
    super.key,
    required this.messageId,
    required this.authoredText,
    required this.translation,
    required this.showTranslation,
    required this.learningLanguageCode,
    required this.interfaceLanguageCode,
    required this.isOutgoing,
    required this.popupTopInset,
    required this.unavailableText,
    required this.retryText,
    this.onRetry,
  });

  final String messageId;
  final String authoredText;
  final AsyncValue<MessageTranslation>? translation;
  final bool showTranslation;
  final String learningLanguageCode;
  final String interfaceLanguageCode;
  final bool isOutgoing;
  final double popupTopInset;
  final String unavailableText;
  final String retryText;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final primaryStyle = TextStyle(
      fontSize: 16,
      height: 1.5,
      color: isOutgoing ? Colors.white : BlabColors.textPrimary,
    );
    final secondaryStyle = TextStyle(
      fontSize: 14,
      height: 1.4,
      color: isOutgoing
          ? Colors.white.withValues(alpha: 0.82)
          : BlabColors.textMuted,
    );
    final result = translation;

    if (!showTranslation || result == null) {
      return Text(authoredText, style: primaryStyle);
    }
    if (result is AsyncLoading<MessageTranslation>) {
      // Most messages resolve to "no aid needed" (same-language chat) —
      // delay the shimmer so that common instant/fast resolutions never
      // flash it. A translation that genuinely takes longer still shows it.
      return _PendingTranslation(
        key: ValueKey('pending-$messageId'),
        authoredText: authoredText,
        primaryStyle: primaryStyle,
        isOutgoing: isOutgoing,
      );
    }
    if (result is AsyncError<MessageTranslation>) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TranslationSubtitle(
            state: TranslationSubtitleState.unavailable,
            text: '',
            isOutgoing: isOutgoing,
            unavailableText: unavailableText,
            retryText: retryText,
            onRetry: onRetry,
            dividerAfter: true,
          ),
          Text(authoredText, style: primaryStyle),
        ],
      );
    }

    final value = (result as AsyncData<MessageTranslation>).value;
    if (value.mode == LearningAidMode.none) {
      return Text(authoredText, style: primaryStyle);
    }

    final senderThirdLanguage =
        isOutgoing &&
        value.sourceLang != learningLanguageCode &&
        value.sourceLang != interfaceLanguageCode;
    final recipientCorrection =
        !isOutgoing && value.mode == LearningAidMode.correction;
    final bottomText = recipientCorrection
        ? value.interfaceText
        : senderThirdLanguage
        ? authoredText
        : value.interfaceText;
    final showBottom = bottomText != value.translation;
    final authorCorrection =
        isOutgoing && value.mode == LearningAidMode.correction;

    final Widget learningLine = authorCorrection
        ? InlineCorrectionText(
            originalText: authoredText,
            correctedText: value.translation,
            style: primaryStyle,
          )
        : MessageText(
            text: value.translation,
            tokens: value.tokens,
            languageCode: learningLanguageCode,
            popupTopInset: popupTopInset,
            style: primaryStyle,
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: kTranslatedMessageMinContentWidth,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          learningLine,
          if (showBottom) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Container(
                height: 1,
                color: isOutgoing
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.grey.shade200,
              ),
            ),
            Text(bottomText, style: secondaryStyle),
          ],
        ],
      ),
    );
  }
}

class _PendingTranslation extends StatefulWidget {
  const _PendingTranslation({
    super.key,
    required this.authoredText,
    required this.primaryStyle,
    required this.isOutgoing,
  });

  final String authoredText;
  final TextStyle primaryStyle;
  final bool isOutgoing;

  @override
  State<_PendingTranslation> createState() => _PendingTranslationState();
}

class _PendingTranslationState extends State<_PendingTranslation> {
  static const _showShimmerAfter = Duration(milliseconds: 350);

  Timer? _timer;
  bool _showShimmer = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_showShimmerAfter, () {
      if (mounted) setState(() => _showShimmer = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showShimmer) {
      return Text(widget.authoredText, style: widget.primaryStyle);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TranslationSubtitle(
          state: TranslationSubtitleState.pending,
          text: '',
          isOutgoing: widget.isOutgoing,
          dividerAfter: true,
        ),
        Text(widget.authoredText, style: widget.primaryStyle),
      ],
    );
  }
}
