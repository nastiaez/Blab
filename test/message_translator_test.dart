import 'dart:async';

import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter_test/flutter_test.dart';

const _messageId = '10000000-0000-4000-8000-000000000001';

Map<String, dynamic> _success() => {
  'translation': 'Hello!',
  'english': 'Hello!',
  'sourceLang': 'ta',
  'tokens': [
    {
      'text': 'வணக்கம்',
      'english': 'Hello',
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
    expect(result.translation, 'Hello!');
    expect(result.englishText, 'Hello!');
    expect(result.sourceLang, 'ta');
    expect(result.tokens, hasLength(2));
    expect(result.tokens.first.text, 'வணக்கம்');
    expect(result.tokens.first.english, 'Hello');
    expect(result.tokens.first.romanization, 'Vaṇakkam');
    expect(result.tokens.first.isContent, isTrue);
    expect(result.tokens.last.text, '!');
    expect(result.tokens.last.isContent, isFalse);
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
