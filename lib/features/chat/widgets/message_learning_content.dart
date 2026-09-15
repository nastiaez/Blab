import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/data/translation_support.dart';
import '../../../shared/models/chat.dart';
import '../../../shared/models/message_token.dart';
import '../../../shared/models/reading_script.dart';
import '../../../shared/services/message_translator.dart';
import '../reading_script_presentation.dart';
import 'inline_correction_text.dart';
import 'message_text.dart';
import 'grammatical_form_chooser.dart';
import '../../../shared/models/grammatical_form.dart';
import '../message_presentation.dart';

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
    this.showOriginal = false,
    this.resolvedSourceLang,
    this.pendingColor,
    this.onRetry,
    this.onFormSelected,
    this.onFormMarkerTap,
    this.resolvedForm,
    this.formAlternativesOverride,
    this.activeFormChoiceIndex = 0,
    this.showFormExplanation = false,
    this.formExplanation,
    this.readingScript = ReadingScript.native,
    this.translationLanguageCode,
  });

  final String authoredText;
  final AsyncValue<MessageTranslation>? translation;
  final bool showTranslation;
  final String learningLanguageCode;
  final bool isOutgoing;
  final double popupTopInset;
  final String unavailableText;
  final String retryText;
  final VoidCallback? onRetry;
  final Future<void> Function(GrammaticalForm form)? onFormSelected;
  final ValueChanged<int>? onFormMarkerTap;
  final GrammaticalForm? resolvedForm;
  final GrammaticalFormAlternatives? formAlternativesOverride;
  final int activeFormChoiceIndex;
  final bool showFormExplanation;
  final String? formExplanation;
  final ReadingScript readingScript;

  /// The actual generated-text target. In Practice this equals
  /// [learningLanguageCode]; in Normal it can be the primary known language.
  final String? translationLanguageCode;

  /// FR-23: practice targets the learning language; normal targets the
  /// reader's known languages, with the source-language bypass below.
  final ChatMode mode;

  /// The reader's known-language codes (normal mode's bypass check only).
  final List<String> knownLanguageCodes;

  /// The source language a *resolution* recorded for this message, if any —
  /// carried separately from [translation] because an `AsyncError` never
  /// carries a value. Null means the app has never learned what language
  /// this message is in. Mode-display-fixes spec § 3 (client-side): normal
  /// mode shows error/retry chrome only when this is non-null and outside
  /// [knownLanguageCodes] — i.e. only when the reader positively cannot
  /// read the message without help.
  final String? resolvedSourceLang;

  /// Whether the practice-mode second (interface-language) lane is open.
  /// Owned by `_Bubble` (Task 10) — this widget only reads it.
  final bool expanded;

  /// Invoked by the icon `_Bubble` builds beside the bubble (Task 10). Not
  /// called from anywhere inside this widget.
  final VoidCallback onToggleExpanded;
  final bool showOriginal;
  final Color? pendingColor;

  @override
  Widget build(BuildContext context) {
    final primaryStyle = TextStyle(
      fontSize: 16,
      height: 1.5,
      color:
          pendingColor ??
          (isOutgoing ? BlabColors.bubbleInk : BlabColors.textPrimary),
    );
    final secondaryStyle = TextStyle(
      fontSize: 14,
      height: 1.4,
      color: isOutgoing
          ? BlabColors.bubbleInk.withValues(alpha: 0.72)
          : BlabColors.textMuted,
    );
    final result = translation;
    final generatedLanguageCode =
        translationLanguageCode ?? learningLanguageCode;

    ReadingScriptPresentation presentGenerated(
      String text,
      List<MessageToken> tokens,
    ) => presentReadingScript(
      text: text,
      tokens: tokens,
      languageCode: generatedLanguageCode,
      readingScript: readingScript,
    );

    Widget generatedMessageText(
      String text,
      List<MessageToken> tokens,
      TextStyle style,
    ) {
      final presentation = presentGenerated(text, tokens);
      return MessageText(
        text: presentation.text,
        tokens: presentation.tokens,
        languageCode: generatedLanguageCode,
        popupTopInset: popupTopInset,
        style: style,
      );
    }

    if (!showTranslation || result == null) {
      return Text(authoredText, style: primaryStyle);
    }

    // Resolve `AsyncData` first — its `value.sourceLang` is what normal
    // mode's known-language bypass needs. Handling it ahead of the
    // loading/error branches (rather than after, as before) means that
    // branching never has to run without the data it needs.
    if (result is AsyncData<MessageTranslation>) {
      final value = result.value;
      if (isUnsupportedSourceText(
        sourceLang: value.sourceLang,
        authoredText: authoredText,
      )) {
        return Text(authoredText, style: primaryStyle);
      }
      // Normal mode preserves authored text when the reader knows its source,
      // even if a cached translation also carries form alternatives.
      if (mode == ChatMode.normal &&
          knownLanguageCodes.contains(value.sourceLang)) {
        return Text(authoredText, style: primaryStyle);
      }
      final formChoices = formAlternativesOverride == null
          ? value.formChoices
          : [formAlternativesOverride!];
      if (formChoices.isNotEmpty &&
          (onFormSelected != null || resolvedForm != null)) {
        if (resolvedForm != null) {
          return generatedMessageText(
            formChoices.first.resolved(resolvedForm!),
            formChoices.first.tokensFor(resolvedForm!).isNotEmpty
                ? formChoices.first.tokensFor(resolvedForm!)
                : resolvedForm == GrammaticalForm.feminine
                ? value.tokens
                : const [],
            primaryStyle,
          );
        }
        return GrammaticalFormAlternativesText(
          alternatives: formChoices.first,
          alternativesList: formChoices,
          style: primaryStyle,
          onMarkerTap: onFormMarkerTap,
          activeIndex: activeFormChoiceIndex,
        );
      }
      if (value.mode == LearningAidMode.none || mode == ChatMode.normal) {
        // Same-language chat (no aid needed, either mode) or normal mode
        // (known source → exact original, unknown → translation only, no
        // second lane): a single plain line, never the shimmer/error chrome
        // or the expand affordance below.
        final displayText = resolveMessageDisplayText(
          authoredText: authoredText,
          value: value,
          mode: mode,
          knownLanguageCodes: knownLanguageCodes,
          targetLanguageCode: generatedLanguageCode,
          readingScript: readingScript,
        );
        final displayWidget = displayText == authoredText
            ? Text(displayText, style: primaryStyle)
            : generatedMessageText(
                value.translation,
                value.tokens,
                primaryStyle,
              );
        if (!showOriginal || displayText == authoredText) {
          return displayWidget;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            displayWidget,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Container(
                height: 1,
                color: isOutgoing
                    ? BlabColors.bubbleInk.withValues(alpha: 0.22)
                    : Colors.grey.shade200,
              ),
            ),
            Text(authoredText, style: secondaryStyle),
          ],
        );
      }
      // Practice mode falls through to the rich rendering below.
    }

    // Loading, both modes: one lane, the authored text, no shimmer and no
    // second lane. "Collapsed is always one lane" applies while the
    // translation resolves too; the swap to the learning-language line is
    // the completion signal.
    if (result is AsyncLoading<MessageTranslation>) {
      return Text(authoredText, style: primaryStyle);
    }

    if (result is AsyncError<MessageTranslation>) {
      // Normal mode only surfaces the failure when the app positively knows
      // the reader needs the translation. Source language never resolved, or
      // resolved to one they already read, means the authored text is either
      // the right answer or the harmless one — render it silently and let the
      // background auto-retry recover. Practice mode always needs the
      // learning-language line, so its failure is always worth reporting.
      final needsTranslation =
          resolvedSourceLang != null &&
          !knownLanguageCodes.contains(resolvedSourceLang);
      if (mode == ChatMode.normal && !needsTranslation) {
        return Text(authoredText, style: primaryStyle);
      }
      return Text(authoredText, style: primaryStyle);
    }

    final value = (result as AsyncData<MessageTranslation>).value;

    // Practice mode: always the learning-language line, collapsible second
    // (interface-language) lane driven by the externally-owned [expanded].
    final authorCorrection =
        isOutgoing && value.mode == LearningAidMode.correction;

    final formChoices = formAlternativesOverride == null
        ? value.formChoices
        : [formAlternativesOverride!];
    final Widget learningLine =
        formChoices.isNotEmpty &&
            (onFormSelected != null || resolvedForm != null)
        ? resolvedForm != null
              ? generatedMessageText(
                  formChoices.first.resolved(resolvedForm!),
                  formChoices.first.tokensFor(resolvedForm!).isNotEmpty
                      ? formChoices.first.tokensFor(resolvedForm!)
                      : resolvedForm == GrammaticalForm.feminine
                      ? value.tokens
                      : const [],
                  primaryStyle,
                )
              : GrammaticalFormAlternativesText(
                  alternatives: formChoices.first,
                  alternativesList: formChoices,
                  style: primaryStyle,
                  onMarkerTap: onFormMarkerTap,
                  activeIndex: activeFormChoiceIndex,
                )
        : authorCorrection
        ? (() {
            final corrected = presentGenerated(value.translation, value.tokens);
            return InlineCorrectionText(
              originalText: authoredText,
              correctedText: corrected.text,
              correctedTokens: corrected.tokens,
              learningLanguageCode: generatedLanguageCode,
              explanation: value.explanation,
              popupTopInset: popupTopInset,
              style: primaryStyle,
            );
          })()
        : generatedMessageText(value.translation, value.tokens, primaryStyle);

    return Column(
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
                  ? BlabColors.bubbleInk.withValues(alpha: 0.22)
                  : Colors.grey.shade200,
            ),
          ),
          Text(value.interfaceText, style: secondaryStyle),
        ],
      ],
    );
  }
}
