import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message_token.dart';

class MessageTranslation {
  const MessageTranslation({
    required this.translation,
    required this.englishText,
    required this.sourceLang,
    required this.tokens,
  });
  final String translation;
  final String englishText;
  final String sourceLang;
  final List<MessageToken> tokens;
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
    final englishText = raw['english'];
    final detectedSourceLang = raw['sourceLang'];
    final rawTokens = raw['tokens'];
    if (translation is! String || translation.trim().isEmpty) {
      throw MessageTranslationFailed('missing_translation');
    }
    if (englishText is! String || englishText.trim().isEmpty) {
      throw MessageTranslationFailed('missing_english');
    }
    if (detectedSourceLang is! String || detectedSourceLang.isEmpty) {
      throw MessageTranslationFailed('missing_source_language');
    }
    final tokens = <MessageToken>[];
    if (rawTokens is List) {
      for (final t in rawTokens) {
        if (t is! Map) continue;
        final tokenText = t['text'];
        if (tokenText is! String) continue;
        final isContent = t['isContent'] as bool? ?? true;
        tokens.add(
          MessageToken(
            text: tokenText,
            english: t['english'] as String?,
            romanization: t['roman'] as String?,
            isContent: isContent,
          ),
        );
      }
    }
    return MessageTranslation(
      translation: translation,
      englishText: englishText,
      sourceLang: detectedSourceLang,
      tokens: tokens,
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
    if (details is Map && details['error'] == 'translation_limit_reached') {
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
    throw MessageTranslationFailed('invoke_failed');
  }
  final data = response.data;
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  throw StateError('unexpected_payload');
}

final messageTranslatorProvider = Provider<MessageTranslator>(
  (ref) => MessageTranslator(),
);
