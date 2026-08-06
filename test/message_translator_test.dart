import 'dart:async';

import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter_test/flutter_test.dart';

const _messageId = '10000000-0000-4000-8000-000000000001';

Map<String, dynamic> _success() => {
  'mode': 'translation',
  'translation': 'வணக்கம்!',
  'interfaceText': 'Привіт!',
  'interfaceLang': 'uk',
  'sourceLang': 'ta',
  'explanation': null,
  'confidence': null,
  'tokens': [
    {
      'text': 'வணக்கம்',
      'gloss': 'Привіт',
      'roman': 'Vaṇakkam',
      'isContent': true,
    },
    {'text': '!', 'isContent': false},
  ],
};

void main() {
  test('parses a successful response into translation + tokens', () async {
    final translator = MessageTranslator(
      invoke: ({required String messageId}) async => _success(),
    );

    final result = await translator.translate(messageId: _messageId);
    expect(result.translation, 'வணக்கம்!');
    expect(result.interfaceText, 'Привіт!');
    expect(result.interfaceLang, 'uk');
    expect(result.sourceLang, 'ta');
    expect(result.mode, LearningAidMode.translation);
    expect(result.tokens, hasLength(2));
    expect(result.tokens.first.text, 'வணக்கம்');
    expect(result.tokens.first.gloss, 'Привіт');
    expect(result.tokens.first.romanization, 'Vaṇakkam');
    expect(result.tokens.first.isContent, isTrue);
    expect(result.tokens.last.text, '!');
    expect(result.tokens.last.isContent, isFalse);
  });

  test('parses a correction with explanation and confidence', () async {
    final translator = MessageTranslator(
      invoke: ({required String messageId}) async => {
        'mode': 'correction',
        'translation': 'Machst du ...?',
        'interfaceText': 'What are you doing?',
        'interfaceLang': 'en',
        'sourceLang': 'de',
        'explanation': 'The verb must agree with "du".',
        'confidence': 'medium',
        'tokens': const [],
      },
    );

    final result = await translator.translate(messageId: _messageId);
    expect(result.mode, LearningAidMode.correction);
    expect(result.translation, 'Machst du ...?');
    expect(result.interfaceText, 'What are you doing?');
    expect(result.explanation, 'The verb must agree with "du".');
    expect(result.confidence, CorrectionConfidence.medium);
  });

  test('drops phrase-sized token metadata from live responses', () async {
    final translator = MessageTranslator(
      invoke: ({required String messageId}) async => {
        'mode': 'translation',
        'translation': 'You can use Google speech.',
        'interfaceText': 'Можна використовувати Google speech.',
        'interfaceLang': 'uk',
        'sourceLang': 'uk',
        'explanation': null,
        'confidence': null,
        'tokens': [
          {
            'text': 'You can use Google speech',
            'gloss': 'whole phrase',
            'roman': null,
            'isContent': true,
          },
          {'text': '.', 'gloss': null, 'roman': null, 'isContent': false},
        ],
      },
    );

    final result = await translator.translate(messageId: _messageId);

    expect(result.translation, 'You can use Google speech.');
    expect(result.tokens, isEmpty);
  });

  test('sends only the trimmed message ID to the invoker', () async {
    String? captured;
    final translator = MessageTranslator(
      invoke: ({required String messageId}) async {
        captured = messageId;
        return _success();
      },
    );

    await translator.translate(messageId: '  $_messageId  ');
    expect(captured, _messageId);
  });

  test('preserves the stable quota failure reason', () async {
    final translator = MessageTranslator(
      invoke: ({required String messageId}) async {
        throw MessageTranslationFailed('translation_limit_reached');
      },
    );

    expect(
      translator.translate(messageId: _messageId),
      throwsA(
        isA<MessageTranslationFailed>().having(
          (error) => error.reason,
          'reason',
          'translation_limit_reached',
        ),
      ),
    );
  });

  test('does not expose arbitrary invoker errors', () async {
    final translator = MessageTranslator(
      invoke: ({required String messageId}) async {
        throw Exception('sensitive provider response');
      },
    );

    expect(
      translator.translate(messageId: _messageId),
      throwsA(
        isA<MessageTranslationFailed>().having(
          (error) => error.reason,
          'reason',
          'invoke_failed',
        ),
      ),
    );
  });

  test('throws when response is malformed', () async {
    final translator = MessageTranslator(
      invoke: ({required String messageId}) async => {'translation': null},
    );

    expect(
      translator.translate(messageId: _messageId),
      throwsA(isA<MessageTranslationFailed>()),
    );
  });

  test('rejects an empty message ID', () async {
    final translator = MessageTranslator(
      invoke: ({required String messageId}) async => _success(),
    );

    expect(
      translator.translate(messageId: '   '),
      throwsA(isA<MessageTranslationFailed>()),
    );
  });

  test('times out when invoker never completes', () async {
    final never = Completer<Map<String, dynamic>>();
    final translator = MessageTranslator(
      invoke: ({required String messageId}) => never.future,
      timeout: const Duration(milliseconds: 10),
    );

    try {
      await translator.translate(messageId: _messageId);
      fail('expected MessageTranslationFailed');
    } on MessageTranslationFailed catch (error) {
      expect(error.reason, 'timeout');
    }
  });
}
