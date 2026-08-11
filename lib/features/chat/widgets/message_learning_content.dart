import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/models/chat.dart';
import '../../../shared/services/message_translator.dart';
import 'inline_correction_text.dart';
import 'message_text.dart';
import 'translation_subtitle.dart';

const double kTranslatedMessageMinContentWidth = 156;

/// Resolves which text to show for a translated message, per the modes/
/// known-languages design spec's § Display logic three rules:
/// - `LearningAidMode.none` (server decided no learning aid is needed, e.g.
///   a same-language chat) → always the exact original.
/// - Practice mode → the learning-language result (`value.translation`,
///   already corrected in place when the author made a mistake).
/// - Normal mode → the exact original when the reader already knows the
///   detected source language, the translation otherwise.
///
/// Shared by [MessageLearningContent]'s normal-mode/no-aid branches below
/// and chat_screen.dart's `_QuotedReply` single-line preview — a second
/// message-rendering path that used to apply none of these rules — so the
/// three-way branch lives in exactly one place.
String resolveMessageDisplayText({
  required String authoredText,
  required MessageTranslation value,
  required ChatMode mode,
  required List<String> knownLanguageCodes,
}) {
  if (value.mode == LearningAidMode.none) return authoredText;
  if (mode == ChatMode.normal) {
    return knownLanguageCodes.contains(value.sourceLang)
        ? authoredText
        : value.translation;
  }
  return value.translation;
}

/// Renders the mode-aware message display contract (FR-23): a single
/// collapsed lane by default. Normal mode either shows the exact original
/// (source language already known) or the bare translation (source
/// unknown) — never both. Practice mode always shows the learning-language
/// line, with a second, interface-language lane that only appears when
/// [expanded] is true. [expanded]/[onToggleExpanded] are lifted state this
/// widget only reads — `_Bubble` owns and resets them (Task 10); this
/// widget has no tappable affordance of its own.
class MessageLearningContent extends StatelessWidget {
  const MessageLearningContent({
    super.key,
    required this.messageId,
    required this.authoredText,
    required this.translation,
    required this.showTranslation,
    required this.learningLanguageCode,
    required this.isOutgoing,
    required this.popupTopInset,
    required this.unavailableText,
    required this.retryText,
    required this.mode,
    required this.knownLanguageCodes,
    required this.expanded,
    required this.onToggleExpanded,
    this.onRetry,
  });

  final String messageId;
  final String authoredText;
  final AsyncValue<MessageTranslation>? translation;
  final bool showTranslation;
  final String learningLanguageCode;
  final bool isOutgoing;
  final double popupTopInset;
  final String unavailableText;
  final String retryText;
  final VoidCallback? onRetry;

  /// FR-23: practice targets the learning language; normal targets the
  /// reader's known languages, with the source-language bypass below.
  final ChatMode mode;

  /// The reader's known-language codes (normal mode's bypass check only).
  final List<String> knownLanguageCodes;

  /// Whether the practice-mode second (interface-language) lane is open.
  /// Owned by `_Bubble` (Task 10) — this widget only reads it.
  final bool expanded;

  /// Invoked by the icon `_Bubble` builds beside the bubble (Task 10). Not
  /// called from anywhere inside this widget.
  final VoidCallback onToggleExpanded;

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

    // Resolve `AsyncData` first — its `value.sourceLang` is what normal
    // mode's known-language bypass needs. Handling it ahead of the
    // loading/error branches (rather than after, as before) means that
    // branching never has to run without the data it needs.
    if (result is AsyncData<MessageTranslation>) {
      final value = result.value;
      if (value.mode == LearningAidMode.none || mode == ChatMode.normal) {
        // Same-language chat (no aid needed, either mode) or normal mode
        // (known source → exact original, unknown → translation only, no
        // second lane): a single plain line, never the shimmer/error chrome
        // or the expand affordance below.
        return Text(
          resolveMessageDisplayText(
            authoredText: authoredText,
            value: value,
            mode: mode,
            knownLanguageCodes: knownLanguageCodes,
          ),
          style: primaryStyle,
        );
      }
      // Practice mode falls through to the rich rendering below.
    } else if (mode == ChatMode.normal) {
      // Finding: normal mode was showing the pending shimmer / a permanent
      // "unavailable + retry" subtitle for messages that might turn out to
      // already be known (source language isn't known yet — the request
      // hasn't resolved). Neither AsyncLoading nor AsyncError carries
      // `sourceLang`, so there's no way to tell here; the safe choice is the
      // plain original with zero AI-request chrome either way — the final
      // answer if the source turns out to be known, an acceptable brief
      // transient state otherwise.
      return Text(authoredText, style: primaryStyle);
    }

    // Practice mode only from here — always needs the learning-language
    // line regardless of known status, so the existing shimmer/retry
    // treatment while it resolves is unchanged.
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

    // Practice mode: always the learning-language line, collapsible second
    // (interface-language) lane driven by the externally-owned [expanded].
    final authorCorrection =
        isOutgoing && value.mode == LearningAidMode.correction;

    final Widget learningLine = authorCorrection
        ? InlineCorrectionText(
            originalText: authoredText,
            correctedText: value.translation,
            learningLanguageCode: learningLanguageCode,
            explanation: value.explanation,
            popupTopInset: popupTopInset,
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
          if (expanded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Container(
                height: 1,
                color: isOutgoing
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.grey.shade200,
              ),
            ),
            Text(value.interfaceText, style: secondaryStyle),
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
