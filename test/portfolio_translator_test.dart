import 'dart:async';

import 'package:blab/shared/services/portfolio_translator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a successful response into translation + tokens', () async {
    final translator = PortfolioTranslator(
      invoke: ({required String text, required String target}) async => {
        'translation': 'வணக்கம்!',
        'tokens': [
          {
            'text': 'வணக்கம்',
            'english': 'Hello',
            'roman': 'Vaṇakkam',
            'isContent': true,
          },
          {'text': '!', 'isContent': false},
        ],
      },
    );

    final result = await translator.translate('Hello!');
    expect(result.tamil, 'வணக்கம்!');
    expect(result.tokens, hasLength(2));
    expect(result.tokens.first.text, 'வணக்கம்');
    expect(result.tokens.first.english, 'Hello');
    expect(result.tokens.first.romanization, 'Vaṇakkam');
    expect(result.tokens.first.isContent, isTrue);
    expect(result.tokens.last.text, '!');
    expect(result.tokens.last.isContent, isFalse);
  });

  test('trims input and skips trailing whitespace before invoking', () async {
    String? captured;
    final translator = PortfolioTranslator(
      invoke: ({required String text, required String target}) async {
        captured = text;
        return {'translation': 'x', 'tokens': <Map<String, dynamic>>[]};
      },
    );

    await translator.translate('  hello world  ');
    expect(captured, 'hello world');
  });

  test('throws PortfolioTranslationFailed when invoker throws', () async {
    final translator = PortfolioTranslator(
      invoke: ({required String text, required String target}) async {
        throw Exception('boom');
      },
    );

    expect(translator.translate('hi'),
        throwsA(isA<PortfolioTranslationFailed>()));
  });

  test('throws PortfolioTranslationFailed when response is malformed',
      () async {
    final translator = PortfolioTranslator(
      invoke: ({required String text, required String target}) async => {
        'translation': null,
      },
    );

    expect(translator.translate('hi'),
        throwsA(isA<PortfolioTranslationFailed>()));
  });

  test('rejects empty / whitespace-only input', () async {
    final translator = PortfolioTranslator(
      invoke: ({required String text, required String target}) async => {},
    );

    expect(translator.translate('   '),
        throwsA(isA<PortfolioTranslationFailed>()));
  });

  test('times out when invoker never completes', () async {
    final never = Completer<Map<String, dynamic>>();
    final translator = PortfolioTranslator(
      invoke: ({required String text, required String target}) => never.future,
      timeout: const Duration(milliseconds: 10),
    );

    try {
      await translator.translate('hi');
      fail('expected PortfolioTranslationFailed');
    } on PortfolioTranslationFailed catch (e) {
      expect(e.reason, 'timeout');
    }
  });
}
