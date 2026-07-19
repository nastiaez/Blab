/// Learning-language codes the live translator covers. Source language is
/// detected by the translation function, so English is also a valid target.
const Set<String> kSupportedLearningLanguages = {
  'en',
  'nl',
  'fr',
  'de',
  'hi',
  'it',
  'pt',
  'es',
  'ta',
  'tr',
  'uk',
};

/// Shared composer and translation-function contract.
const int kMaxMessageCharacters = 2000;

/// A language change only applies to messages sent from that moment onward.
/// Older messages remain visible as authored and never enter
/// the translation cache for the newly selected language.
bool shouldTranslateMessage({
  required DateTime sentAt,
  required DateTime? translationCutoffAt,
}) => translationCutoffAt == null || !sentAt.isBefore(translationCutoffAt);

bool shouldRequestTranslation({
  required bool showTranslations,
  required String learningLanguageCode,
  required String text,
  required DateTime sentAt,
  required DateTime? translationCutoffAt,
}) =>
    showTranslations &&
    kSupportedLearningLanguages.contains(learningLanguageCode) &&
    text.trim().isNotEmpty &&
    shouldTranslateMessage(
      sentAt: sentAt,
      translationCutoffAt: translationCutoffAt,
    );

bool shouldRequestBubbleTranslation({
  required bool showTranslations,
  required String learningLanguageCode,
  required String text,
  required DateTime sentAt,
  required DateTime? translationCutoffAt,
}) => shouldRequestTranslation(
  showTranslations: showTranslations,
  learningLanguageCode: learningLanguageCode,
  text: text,
  sentAt: sentAt,
  translationCutoffAt: translationCutoffAt,
);
