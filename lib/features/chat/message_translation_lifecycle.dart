import '../../shared/services/message_translator.dart';
export '../../shared/data/translation_support.dart'
    show containsMeaningBearingText;

enum TranslationSpeedBranch { fast, medium, slow }

TranslationSpeedBranch translationSpeedBranch(Duration elapsed) {
  if (elapsed < const Duration(milliseconds: 180)) {
    return TranslationSpeedBranch.fast;
  }
  if (elapsed < const Duration(milliseconds: 350)) {
    return TranslationSpeedBranch.medium;
  }
  return TranslationSpeedBranch.slow;
}

bool shouldHoldIncomingTranslation({
  required bool isOutgoing,
  required bool processing,
  required bool originalWasRevealedAfterFailure,
}) => !isOutgoing && processing && !originalWasRevealedAfterFailure;

bool shouldShowPendingTranslationGroupStatus(int pendingCount) =>
    pendingCount > 1;

bool translationResultIsUnchanged(
  String authoredText,
  MessageTranslation result,
) =>
    result.mode != LearningAidMode.correction &&
    result.formAlternatives == null &&
    result.translation == authoredText;
