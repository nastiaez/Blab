import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message_token.dart';

enum LearningAidMode { translation, correction, none }

enum CorrectionConfidence { low, medium, high }

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
  });
  final String translation;
  final String interfaceText;
  final String interfaceLang;
  final String sourceLang;
  final List<MessageToken> tokens;
  final LearningAidMode mode;
  final String? explanation;
  final CorrectionConfidence? confidence;
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
  }) : _invoke = invoke ?? _defaultInvoke,
       _timeout = timeout;

  final MessageTranslateInvoke _invoke;
  final Duration _timeout;

  Future<MessageTranslation> translate({required String messageId}) async {
    if (messageId.trim().isEmpty) {
      throw MessageTranslationFailed('invalid_message_id');
    }
    Map<String, dynamic> raw;
    try {
      raw = await _invoke(messageId: messageId.trim()).timeout(_timeout);
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
    if (translation is! String || translation.trim().isEmpty) {
      throw MessageTranslationFailed('missing_translation');
    }
    if (interfaceText is! String || interfaceText.trim().isEmpty) {
      throw MessageTranslationFailed('missing_interface_text');
    }
    if (interfaceLang is! String ||
        !const {'en', 'uk', 'de', 'es'}.contains(interfaceLang)) {
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
    );
  }
}

Future<Map<String, dynamic>> _defaultInvoke({required String messageId}) async {
  FunctionResponse response;
  try {
    response = await Supabase.instance.client.functions.invoke(
      'translate-message',
      body: {'messageId': messageId},
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
