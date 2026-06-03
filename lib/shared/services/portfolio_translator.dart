import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message_token.dart';

class PortfolioTranslation {
  const PortfolioTranslation({required this.tamil, required this.tokens});
  final String tamil;
  final List<MessageToken> tokens;
}

class PortfolioTranslationFailed implements Exception {
  PortfolioTranslationFailed(this.reason);
  final String reason;
  @override
  String toString() => 'PortfolioTranslationFailed: $reason';
}

/// Injectable invoker. Production wires this to a real Supabase Edge
/// Function call; tests pass a fake.
typedef PortfolioTranslateInvoke = Future<Map<String, dynamic>> Function({
  required String text,
  required String target,
});

class PortfolioTranslator {
  PortfolioTranslator({
    PortfolioTranslateInvoke? invoke,
    Duration timeout = const Duration(seconds: 15),
  })  : _invoke = invoke ?? _defaultInvoke,
        _timeout = timeout;

  final PortfolioTranslateInvoke _invoke;
  final Duration _timeout;

  Future<PortfolioTranslation> translate(String englishText) async {
    final trimmed = englishText.trim();
    if (trimmed.isEmpty) {
      throw PortfolioTranslationFailed('empty_input');
    }
    Map<String, dynamic> raw;
    try {
      raw = await _invoke(text: trimmed, target: 'ta').timeout(_timeout);
    } on TimeoutException {
      throw PortfolioTranslationFailed('timeout');
    } catch (e) {
      throw PortfolioTranslationFailed('invoke_failed: $e');
    }
    final translation = raw['translation'];
    final rawTokens = raw['tokens'];
    if (translation is! String || translation.isEmpty) {
      throw PortfolioTranslationFailed('missing_translation');
    }
    final tokens = <MessageToken>[];
    if (rawTokens is List) {
      for (final t in rawTokens) {
        if (t is! Map) continue;
        final text = t['text'];
        if (text is! String) continue;
        final isContent = t['isContent'] as bool? ?? true;
        tokens.add(MessageToken(
          text: text,
          english: t['english'] as String?,
          romanization: t['roman'] as String?,
          isContent: isContent,
        ));
      }
    }
    return PortfolioTranslation(tamil: translation, tokens: tokens);
  }
}

Future<Map<String, dynamic>> _defaultInvoke({
  required String text,
  required String target,
}) async {
  final response = await Supabase.instance.client.functions.invoke(
    'translate-portfolio',
    body: {'text': text, 'target': target},
  );
  final data = response.data;
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  throw StateError('unexpected_payload');
}

final portfolioTranslatorProvider =
    Provider<PortfolioTranslator>((ref) => PortfolioTranslator());
