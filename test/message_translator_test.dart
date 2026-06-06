import 'dart:async';

import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a successful response into translation + tokens', () async {
    final translator = MessageTranslator(
      invoke: ({
        required String text,
        required String sourceLang,
        required String targetLang,
      }) async => {
        'translation': 'Hello!',
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

    final result = await translator.translate(
      text: 'வணக்கம்!',
      sourceLang: 'ta',
      targetLang: 'en',
    );
    expect(result.translation, 'Hello!');
    expect(result.tokens, hasLength(2));
    expect(result.tokens.first.text, 'வணக்கம்');
    expect(result.tokens.first.english, 'Hello');
    expect(result.tokens.first.romanization, 'Vaṇakkam');
    expect(result.tokens.first.isContent, isTrue);
    expect(result.tokens.last.text, '!');
    expect(result.tokens.last.isContent, isFalse);
  });

  test('passes source + target lang through to the invoker', () async {
    String? capturedSource;
    String? capturedTarget;
    final translator = MessageTranslator(
      invoke: ({
        required String text,
        required String sourceLang,
        required String targetLang,
      }) async {
        capturedSource = sourceLang;
        capturedTarget = targetLang;
        return {'translation': 'x', 'tokens': <Map<String, dynamic>>[]};
      },
    );

    await translator.translate(
      text: 'வணக்கம்',
      sourceLang: 'ta',
      targetLang: 'en',
    );
    expect(capturedSource, 'ta');
    expect(capturedTarget, 'en');
  });

  test('trims input before invoking', () async {
    String? captured;
    final translator = MessageTranslator(
      invoke: ({
        required String text,
        required String sourceLang,
        required String targetLang,
      }) async {
        captured = text;
        return {'translation': 'x', 'tokens': <Map<String, dynamic>>[]};
      },
    );

    await translator.translate(
      text: '  வணக்கம்  ',
      sourceLang: 'ta',
      targetLang: 'en',
    );
    expect(captured, 'வணக்கம்');
  });

  test('throws MessageTranslationFailed when invoker throws', () async {
    final translator = MessageTranslator(
      invoke: ({
        required String text,
        required String sourceLang,
        required String targetLang,
      }) async {
        throw Exception('boom');
      },
    );

    expect(
      translator.translate(text: 'hi', sourceLang: 'ta', targetLang: 'en'),
      throwsA(isA<MessageTranslationFailed>()),
    );
  });

  test('throws MessageTranslationFailed when response is malformed', () async {
    final translator = MessageTranslator(
      invoke: ({
        required String text,
        required String sourceLang,
        required String targetLang,
      }) async => {'translation': null},
    );

    expect(
      translator.translate(text: 'hi', sourceLang: 'ta', targetLang: 'en'),
      throwsA(isA<MessageTranslationFailed>()),
    );
  });

  test('rejects empty / whitespace-only input', () async {
    final translator = MessageTranslator(
      invoke: ({
        required String text,
        required String sourceLang,
        required String targetLang,
      }) async => {},
    );

    expect(
      translator.translate(text: '   ', sourceLang: 'ta', targetLang: 'en'),
      throwsA(isA<MessageTranslationFailed>()),
    );
  });

  test('times out when invoker never completes', () async {
    final never = Completer<Map<String, dynamic>>();
    final translator = MessageTranslator(
      invoke: ({
        required String text,
        required String sourceLang,
        required String targetLang,
      }) => never.future,
      timeout: const Duration(milliseconds: 10),
    );

    try {
      await translator.translate(
        text: 'வணக்கம்',
        sourceLang: 'ta',
        targetLang: 'en',
      );
      fail('expected MessageTranslationFailed');
    } on MessageTranslationFailed catch (e) {
      expect(e.reason, 'timeout');
    }
  });
}
