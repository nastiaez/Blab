import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/data/translation_support.dart';
import '../../shared/models/chat.dart';
import '../../shared/services/message_translator.dart';

class MessagePresentation {
  const MessagePresentation({
    required this.primaryText,
    required this.originalText,
    required this.canRevealOriginal,
    this.knownLanguageText,
    this.listenText,
    this.translationFailed = false,
    this.unsupportedSource = false,
  });

  final String primaryText;
  final String originalText;
  final bool canRevealOriginal;
  final String? knownLanguageText;
  final String? listenText;
  final bool translationFailed;
  final bool unsupportedSource;
}

String resolveMessageDisplayText({
  required String authoredText,
  required MessageTranslation value,
  required ChatMode mode,
  required List<String> knownLanguageCodes,
}) {
  if (isUnsupportedSourceText(
    sourceLang: value.sourceLang,
    authoredText: authoredText,
  )) {
    return authoredText;
  }
  if (value.mode == LearningAidMode.none) return authoredText;
  if (mode == ChatMode.normal) {
    return knownLanguageCodes.contains(value.sourceLang)
        ? authoredText
        : value.translation;
  }
  return value.translation;
}

MessagePresentation resolveMessagePresentation({
  required String authoredText,
  required AsyncValue<MessageTranslation>? translation,
  required ChatMode mode,
  required List<String> knownLanguageCodes,
  String? resolvedSourceLang,
}) {
  if (translation case AsyncData<MessageTranslation>(value: final value)) {
    final primaryText = resolveMessageDisplayText(
      authoredText: authoredText,
      value: value,
      mode: mode,
      knownLanguageCodes: knownLanguageCodes,
    );
    final unsupportedSource = isUnsupportedSourceText(
      sourceLang: value.sourceLang,
      authoredText: authoredText,
    );
    final practiceAid =
        mode == ChatMode.practice &&
        value.mode != LearningAidMode.none &&
        !unsupportedSource;
    return MessagePresentation(
      primaryText: primaryText,
      originalText: authoredText,
      canRevealOriginal:
          mode == ChatMode.normal &&
          authoredText.trim().isNotEmpty &&
          primaryText != authoredText,
      knownLanguageText: practiceAid ? value.interfaceText : null,
      listenText: practiceAid && primaryText.trim().isNotEmpty
          ? primaryText
          : null,
      unsupportedSource: unsupportedSource,
    );
  }

  final failed = translation is AsyncError<MessageTranslation>;
  final needsTranslation =
      mode == ChatMode.practice ||
      (resolvedSourceLang != null &&
          !knownLanguageCodes.contains(resolvedSourceLang));
  return MessagePresentation(
    primaryText: authoredText,
    originalText: authoredText,
    canRevealOriginal: false,
    translationFailed: failed && needsTranslation,
  );
}
