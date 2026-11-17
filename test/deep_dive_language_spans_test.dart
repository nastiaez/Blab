import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'script ledger covers exact supported catalogue, not just UI locales',
    () {
      expect(kBlabLanguages.map((l) => l.code).toSet(), {
        'da',
        'nl',
        'en',
        'fi',
        'fr',
        'de',
        'hi',
        'it',
        'ko',
        'mr',
        'pl',
        'pt',
        'es',
        'ta',
        'tr',
        'uk',
      });
    },
  );
  for (final language in kBlabLanguages) {
    test(
      '${language.code} repeated words preserve UTF16 ranges after emoji',
      () {
        final word = language.hello;
        final text = '🙂 $word, $word!';
        final tokens = messageTokensForText(text);
        expect(tokens.map((t) => t.text).join(), text);
        var offset = 0;
        final starts = <int>[];
        for (final token in tokens) {
          expect(
            text.substring(offset, offset + token.text.length),
            token.text,
          );
          if (token.isContent) starts.add(offset);
          offset += token.text.length;
        }
        expect(offset, text.length);
        expect(starts.first, 3);
        expect(starts.contains(text.lastIndexOf(word)), isTrue);
        expect(
          tokens
              .where((t) => t.isContent)
              .map((t) => t.text)
              .join(' ')
              .contains(word),
          isTrue,
        );
      },
    );
  }
  test(
    'multiword provider metadata cannot manufacture an unrelated tap range',
    () {
      const text = 'guten Morgen';
      final tokens = messageTokensForText(
        text,
        metadata: const [MessageToken(text: text, gloss: 'good morning')],
      );
      expect(tokens.where((t) => t.isContent).map((t) => t.text), [
        'guten',
        'Morgen',
      ]);
      expect(tokens.map((t) => t.text).join(), text);
    },
  );
  test(
    'separable expression remains separate spans; no false phrase-selection claim',
    () {
      const text = 'Ich stehe um sieben auf.';
      final parts = messageTokensForText(
        text,
      ).where((t) => t.isContent).map((t) => t.text).toList();
      expect(parts.contains('stehe'), isTrue);
      expect(parts.contains('auf'), isTrue);
      expect(
        parts.any((t) => t.contains('stehe') && t.contains('auf')),
        isFalse,
      );
    },
  );
}
