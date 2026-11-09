import 'package:blab/shared/services/chat_service.dart';
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
  test('missing correction details survive readable-package serialization', () {
    final row = <String, dynamic>{
      'message_id': _messageId,
      'target_lang': 'de',
      'interface_lang': 'en',
      'learning_language': 'de',
      'result': {
        ..._success(),
        'translation': 'Ich bin müde.',
        'interfaceText': 'I am tired.',
        'sourceLang': 'de',
        'mode': 'correction',
        'explanation': null,
        'confidence': null,
      },
    };
    final changes = readableTranslationChanges(row);
    expect(changes.first.translation.text, 'Ich bin müde.');
    expect(changes.first.translation.explanation, isNull);
    expect(changes.first.translation.confidence, isNull);
    final package = readablePreparedPackage(row)!;
    expect(package['translation_text'], 'Ich bin müde.');
    expect(package['explanation'], isNull);
    expect(package['confidence'], isNull);
  });

  test(
    'malformed optional confidence cannot reject the sentence or become high',
    () async {
      final result = await MessageTranslator(
        invoke: ({required String messageId}) async => {
          ..._success(),
          'mode': 'correction',
          'confidence': 'unsupported',
          'explanation': 123,
        },
      ).translate(messageId: _messageId);
      expect(result.translation, _success()['translation']);
      expect(result.confidence, isNull);
      expect(result.explanation, isNull);
    },
  );

  for (final missing in ['explanation', 'confidence']) {
    test('usable correction survives missing $missing', () async {
      final raw = {
        ..._success(),
        'mode': 'correction',
        'translation': 'Ich bin müde.',
        'sourceLang': 'de',
        'explanation': 'Use bin.',
        'confidence': 'high',
      };
      raw[missing] = null;
      final result = await MessageTranslator(
        invoke: ({required String messageId}) async => raw,
      ).translate(messageId: _messageId);
      expect(result.translation, 'Ich bin müde.');
      expect(
        result.confidence,
        missing == 'confidence' ? isNull : CorrectionConfidence.high,
      );
      expect(
        result.explanation,
        missing == 'explanation' ? isNull : 'Use bin.',
      );
    });
  }

  test('live response retains trusted mention identity sidecar', () async {
    final translator = MessageTranslator(
      invoke: ({required String messageId}) async => {
        ..._success(),
        'translation': 'Hello @Alex',
        'interfaceText': 'Hi @Alex',
        'tokens': [
          {
            'blabMentionSpans': {
              'Hello @Alex': [
                {'userId': 'account-1', 'label': 'Alex', 'start': 6},
              ],
            },
          },
        ],
      },
    );
    final result = await translator.translate(messageId: _messageId);
    expect(result.mentionSpans['Hello @Alex']!.single.userId, 'account-1');
  });
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
