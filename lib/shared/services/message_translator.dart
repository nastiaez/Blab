import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message_token.dart';

class MessageTranslation {
  const MessageTranslation({required this.translation, required this.tokens});
  final String translation;
  final List<MessageToken> tokens;
}

class MessageTranslationFailed implements Exception {
  MessageTranslationFailed(this.reason);
  final String reason;
  @override
  String toString() => 'MessageTranslationFailed: $reason';
}

/// Injectable invoker. Production wires to a real Supabase Edge Function
/// call; tests pass a fake.
typedef MessageTranslateInvoke = Future<Map<String, dynamic>> Function({
  required String text,
  required String sourceLang,
  required String targetLang,
});

class MessageTranslator {
  MessageTranslator({
    MessageTranslateInvoke? invoke,
    Duration timeout = const Duration(seconds: 15),
  })  : _invoke = invoke ?? _defaultInvoke,
        _timeout = timeout;

  final MessageTranslateInvoke _invoke;
  final Duration _timeout;

  Future<MessageTranslation> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw MessageTranslationFailed('empty_input');
    }
    Map<String, dynamic> raw;
    try {
      raw = await _invoke(
        text: trimmed,
        sourceLang: sourceLang,
        targetLang: targetLang,
      ).timeout(_timeout);
    } on TimeoutException {
      throw MessageTranslationFailed('timeout');
    } catch (e) {
      throw MessageTranslationFailed('invoke_failed: $e');
    }
    final translation = raw['translation'];
    final rawTokens = raw['tokens'];
    if (translation is! String || translation.isEmpty) {
      throw MessageTranslationFailed('missing_translation');
    }
    final tokens = <MessageToken>[];
    if (rawTokens is List) {
      for (final t in rawTokens) {
        if (t is! Map) continue;
        final tokenText = t['text'];
        if (tokenText is! String) continue;
        final isContent = t['isContent'] as bool? ?? true;
        tokens.add(MessageToken(
          text: tokenText,
          english: t['english'] as String?,
          romanization: t['roman'] as String?,
          isContent: isContent,
        ));
      }
    }
    return MessageTranslation(translation: translation, tokens: tokens);
  }
}

Future<Map<String, dynamic>> _defaultInvoke({
  required String text,
  required String sourceLang,
  required String targetLang,
}) async {
  final response = await Supabase.instance.client.functions.invoke(
    'translate-message',
    body: {
      'text': text,
      'sourceLang': sourceLang,
      'targetLang': targetLang,
    },
  );
  final data = response.data;
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  throw StateError('unexpected_payload');
}

final messageTranslatorProvider =
    Provider<MessageTranslator>((ref) => MessageTranslator());
