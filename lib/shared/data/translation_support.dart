import '../models/chat.dart';

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

/// Resolves which language a message's learning aid should target.
///
/// Practice mode always targets the chat's learning language — there is no
/// known-language exception, full stop (PRD FR-23). Normal mode targets the
/// reader's primary known language instead, so a bilingual conversation
/// reads in whichever language the reader is fluent in.
String resolveTranslationTarget({
  required ChatMode mode,
  required String learningLanguageCode,
  required String primaryKnownLanguageCode,
}) => mode == ChatMode.practice
    ? learningLanguageCode
    : primaryKnownLanguageCode;

/// Whether a live/cached translation should be requested for [text], given
/// the resolved [targetLanguageCode]. There is no global on/off switch
/// anymore — eligibility is purely a function of mode-resolved target,
/// translator coverage, message content, and the translation cutoff.
bool shouldRequestTranslation({
  required String targetLanguageCode,
  required String text,
  required DateTime sentAt,
  required DateTime? translationCutoffAt,
}) =>
    kSupportedLearningLanguages.contains(targetLanguageCode) &&
    text.trim().isNotEmpty &&
    shouldTranslateMessage(
      sentAt: sentAt,
      translationCutoffAt: translationCutoffAt,
    );

bool shouldRequestBubbleTranslation({
  required String targetLanguageCode,
  required String text,
  required DateTime sentAt,
  required DateTime? translationCutoffAt,
}) => shouldRequestTranslation(
  targetLanguageCode: targetLanguageCode,
  text: text,
  sentAt: sentAt,
  translationCutoffAt: translationCutoffAt,
);
