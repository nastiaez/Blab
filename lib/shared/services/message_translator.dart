import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/translation_support.dart';
import '../models/message_token.dart';
import '../models/grammatical_form.dart';

enum LearningAidMode { translation, correction, none }

enum CorrectionConfidence { low, medium, high }

/// A natural, linked grammatical-form choice returned only when the target
/// sentence cannot be completed safely without one. The surrounding fragments
/// keep word order intact for multi-word agreement. US-042 / FR-34.
class GrammaticalFormAlternatives {
  const GrammaticalFormAlternatives({
    required this.before,
    required this.feminine,
    required this.masculine,
    required this.after,
    required this.subjectName,
    required this.subjectIsViewer,
  });

  final String before;
  final String feminine;
  final String masculine;
  final String after;
  final String subjectName;
  final bool subjectIsViewer;

  String resolved(GrammaticalForm form) =>
      '$before${form == GrammaticalForm.feminine ? feminine : masculine}$after';
}

class MessageTranslation {
  const MessageTranslation({
    required this.translation,
    required this.interfaceText,
    required this.interfaceLang,
    required this.sourceLang,
    required this.tokens,
    this.mode = LearningAidMode.translation,
    this.explanation,
    this.confidence,
    this.formAlternatives,
    this.formAlternativesList,
  });
  final String translation;
  final String interfaceText;
  final String interfaceLang;
  final String sourceLang;
  final List<MessageToken> tokens;
  final LearningAidMode mode;
  final String? explanation;
  final CorrectionConfidence? confidence;
  final GrammaticalFormAlternatives? formAlternatives;

  /// All unresolved subjects returned by the translation contract. The
  /// singular field remains for compatibility with older cached rows and is
  /// always the first entry when this list is populated.
  final List<GrammaticalFormAlternatives>? formAlternativesList;

  List<GrammaticalFormAlternatives> get formChoices =>
      formAlternativesList ??
      (formAlternatives == null
          ? const <GrammaticalFormAlternatives>[]
          : <GrammaticalFormAlternatives>[formAlternatives!]);
}

class MessageTranslationFailed implements Exception {
  MessageTranslationFailed(this.reason, {this.retryAfter});
  final String reason;
  final Duration? retryAfter;
  @override
  String toString() => 'MessageTranslationFailed: $reason';
}

/// Injectable invoker. Production wires to a real Supabase Edge Function
/// call; tests pass a fake.
typedef MessageTranslateInvoke =
    Future<Map<String, dynamic>> Function({required String messageId});

class MessageTranslator {
  MessageTranslator({
    MessageTranslateInvoke? invoke,
    Duration timeout = const Duration(seconds: 60),
  }) : _invoke = invoke,
       _timeout = timeout;

  final MessageTranslateInvoke? _invoke;
  final Duration _timeout;

  Future<MessageTranslation> translate({required String messageId}) async {
    return _translate(messageId: messageId, forceRefresh: false);
  }

  Future<MessageTranslation> translateFresh({required String messageId}) async {
    return _translate(messageId: messageId, forceRefresh: true);
  }

  Future<MessageTranslation> _translate({
    required String messageId,
    required bool forceRefresh,
  }) async {
    if (messageId.trim().isEmpty) {
      throw MessageTranslationFailed('invalid_message_id');
    }
    Map<String, dynamic> raw;
    try {
      final invoke = _invoke;
      raw =
          await (invoke == null
                  ? _defaultInvoke(
                      messageId: messageId.trim(),
                      forceRefresh: forceRefresh,
                    )
                  : invoke(messageId: messageId.trim()))
              .timeout(_timeout);
    } on TimeoutException {
      throw MessageTranslationFailed('timeout');
    } on MessageTranslationFailed {
      rethrow;
    } catch (_) {
      throw MessageTranslationFailed('invoke_failed');
    }
    final translation = raw['translation'];
    final interfaceText = raw['interfaceText'];
    final rawMode = raw['mode'];
    final interfaceLang = raw['interfaceLang'];
    final detectedSourceLang = raw['sourceLang'];
    final rawExplanation = raw['explanation'];
    final rawConfidence = raw['confidence'];
    final rawTokens = raw['tokens'];
    final alternativesList = parseGrammaticalFormAlternativesList(
      raw['formAlternatives'],
    );
    final alternatives = alternativesList.isEmpty
        ? null
        : alternativesList.first;
    if (translation is! String || translation.trim().isEmpty) {
      throw MessageTranslationFailed('missing_translation');
    }
    if (interfaceText is! String || interfaceText.trim().isEmpty) {
      throw MessageTranslationFailed('missing_interface_text');
    }
    // modes-known-languages spec: the server's `interfaceLang` slot is the
    // reader's primary known language (falling back to interface_language
    // only when unset) — any of the 11 learning languages, not just the 4
    // interface-language locales.
    if (interfaceLang is! String ||
        !kSupportedLearningLanguages.contains(interfaceLang)) {
      throw MessageTranslationFailed('missing_interface_language');
    }
    if (detectedSourceLang is! String || detectedSourceLang.isEmpty) {
      throw MessageTranslationFailed('missing_source_language');
    }
    final mode = switch (rawMode) {
      'translation' => LearningAidMode.translation,
      'correction' => LearningAidMode.correction,
      'none' => LearningAidMode.none,
      _ => throw MessageTranslationFailed('missing_learning_aid_mode'),
    };
    final confidence = switch (rawConfidence) {
      'low' => CorrectionConfidence.low,
      'medium' => CorrectionConfidence.medium,
      'high' => CorrectionConfidence.high,
      null => null,
      _ => throw MessageTranslationFailed('invalid_correction_confidence'),
    };
    if (mode == LearningAidMode.correction &&
        (rawExplanation is! String ||
            rawExplanation.trim().isEmpty ||
            confidence == null)) {
      throw MessageTranslationFailed('missing_correction_details');
    }
    final rawParsedTokens = <MessageToken>[];
    if (rawTokens is List) {
      for (final t in rawTokens) {
        if (t is! Map) continue;
        final tokenText = t['text'];
        if (tokenText is! String) continue;
        final isContent = t['isContent'] as bool? ?? true;
        rawParsedTokens.add(
          MessageToken(
            text: tokenText,
            gloss: t['gloss'] as String?,
            romanization: t['roman'] as String?,
            isContent: isContent,
          ),
        );
      }
    }
    return MessageTranslation(
      translation: translation,
      interfaceText: interfaceText,
      interfaceLang: interfaceLang,
      sourceLang: detectedSourceLang,
      tokens: sanitizeMessageTokens(rawParsedTokens, translation),
      mode: mode,
      explanation: mode == LearningAidMode.correction
          ? (rawExplanation as String).trim()
          : null,
      confidence: mode == LearningAidMode.correction ? confidence : null,
      formAlternatives: alternatives,
      formAlternativesList: alternativesList,
    );
  }
}

GrammaticalFormAlternatives? parseGrammaticalFormAlternatives(Object? raw) {
  if (raw is! Map) return null;
  final before = raw['before'];
  final feminine = raw['feminine'];
  final masculine = raw['masculine'];
  final after = raw['after'];
  final subjectName = raw['subjectName'];
  final subjectIsViewer = raw['subjectIsViewer'];
  if (before is! String ||
      feminine is! String ||
      masculine is! String ||
      after is! String ||
      subjectName is! String ||
      subjectIsViewer is! bool ||
      feminine.trim().isEmpty ||
      masculine.trim().isEmpty) {
    return null;
  }
  return GrammaticalFormAlternatives(
    before: before,
    feminine: feminine,
    masculine: masculine,
    after: after,
    subjectName: subjectName,
    subjectIsViewer: subjectIsViewer,
  );
}

List<GrammaticalFormAlternatives> parseGrammaticalFormAlternativesList(
  Object? raw,
) {
  final values = raw is List ? raw : <Object?>[raw];
  return values
      .map(parseGrammaticalFormAlternatives)
      .whereType<GrammaticalFormAlternatives>()
      .toList(growable: false);
}

Future<Map<String, dynamic>> _defaultInvoke({
  required String messageId,
  bool forceRefresh = false,
}) async {
  FunctionResponse response;
  try {
    response = await Supabase.instance.client.functions.invoke(
      'translate-message',
      body: {'messageId': messageId, if (forceRefresh) 'forceRefresh': true},
    );
  } on FunctionException catch (error) {
    final details = error.details;
    final reason = details is Map ? details['error']?.toString() : null;
    final diagnostic = details is Map ? details['reason']?.toString() : null;
    if (kDebugMode) {
      debugPrint(
        'Translation function failed: status=${error.status}, '
        'reason=${reason ?? 'unknown'}, '
        'diagnostic=${diagnostic ?? 'none'}',
      );
    }
    if (reason == 'translation_limit_reached') {
      final rawRetryAfter = details['retryAfterSeconds'];
      final retryAfterSeconds = switch (rawRetryAfter) {
        num value => value.ceil(),
        String value => int.tryParse(value),
        _ => null,
      };
      throw MessageTranslationFailed(
        'translation_limit_reached',
        retryAfter: retryAfterSeconds == null
            ? null
            : Duration(seconds: retryAfterSeconds.clamp(1, 86400)),
      );
    }
    throw MessageTranslationFailed(reason ?? 'invoke_failed');
  }
  final data = response.data;
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  throw StateError('unexpected_payload');
}

final messageTranslatorProvider = Provider<MessageTranslator>(
  (ref) => MessageTranslator(),
);
