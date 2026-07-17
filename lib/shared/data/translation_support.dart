/// Learning-language codes the live translator covers. Every Blab
/// language except English — in v1 both sides type English, so a chat
/// whose viewer is "learning English" needs no translation.
const Set<String> kSupportedLearningLanguages = {
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

/// A language change only applies to messages sent from that moment onward.
/// Older messages remain visible as their English originals and never enter
/// the translation cache for the newly selected language.
bool shouldTranslateMessage({
  required DateTime sentAt,
  required DateTime? translationCutoffAt,
}) => translationCutoffAt == null || !sentAt.isBefore(translationCutoffAt);
