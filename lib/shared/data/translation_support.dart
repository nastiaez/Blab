import '../models/chat.dart';

/// Learning-language codes the live translator covers. Source language is
/// detected by the translation function, so English is also a valid target.
const String kOtherSourceLanguage = 'other';

/// Source detection can classify highly stylized chat text as `other` even
/// when it is an expressive form of a supported language. Keep those messages
/// in the normal translation path; the original spelling remains authoritative.
bool isExpressiveLanguageVariant(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  if (RegExp(r'([a-zа-яіїєґ])\1{2,}', caseSensitive: false).hasMatch(trimmed)) {
    return true;
  }
  return RegExp(
    r'^(omg|ttyl|brb|lol|lmao|idk|fyi|wtf)[!?.,…]*$',
    caseSensitive: false,
  ).hasMatch(trimmed);
}

bool isUnsupportedSourceText({
  required String sourceLang,
  required String authoredText,
}) =>
    sourceLang == kOtherSourceLanguage &&
    !isExpressiveLanguageVariant(authoredText);

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

bool containsMeaningBearingText(String text) {
  var candidate = text;
  candidate = candidate.replaceAll(
    RegExp(r'```[\s\S]*?```|`[^`]*`', multiLine: true),
    ' ',
  );
  candidate = candidate.replaceAll(
    RegExp(r'(?:https?://|www\.)\S+', caseSensitive: false),
    ' ',
  );
  candidate = candidate.replaceAll(RegExp(r'(^|\s)[@#]\S+'), ' ');
  candidate = candidate.replaceAll(
    RegExp(r'\b\d+(?:[.:]\d+)?(?:am|pm)?\b', caseSensitive: false),
    ' ',
  );

  bool isProtectedRune(int rune) =>
      (rune >= 0x1F000 && rune <= 0x1FAFF) ||
      (rune >= 0x2600 && rune <= 0x27BF) ||
      (rune >= 0x1F1E6 && rune <= 0x1F1FF) ||
      (rune >= 0x1F3FB && rune <= 0x1F3FF) ||
      rune == 0x200D ||
      rune == 0x20E3 ||
      rune == 0xFE0E ||
      rune == 0xFE0F;

  candidate = String.fromCharCodes(
    candidate.runes.where((rune) => !isProtectedRune(rune)),
  );
  return candidate.runes.any((rune) {
    final character = String.fromCharCode(rune);
    return RegExp(
      r'[A-Za-z\u00C0-\u024F\u0370-\u052F\u0900-\u097F\u0B80-\u0BFF\u3400-\u4DBF\u4E00-\u9FFF\u3040-\u30FF\uAC00-\uD7AF]',
    ).hasMatch(character);
  });
}

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
}) =>
    mode == ChatMode.practice ? learningLanguageCode : primaryKnownLanguageCode;

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
    containsMeaningBearingText(text) &&
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
