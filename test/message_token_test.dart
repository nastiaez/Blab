import 'package:blab/shared/models/message_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('word metadata survives provider punctuation and spacing drift', () {
    final tokens = messageTokensForText(
      '¿Cuál es el plan?',
      metadata: const [
        MessageToken(text: '¿Cuál', gloss: 'What', isContent: true),
        MessageToken(text: ' es', gloss: 'is', isContent: true),
        MessageToken(text: ' el', gloss: 'the', isContent: true),
        MessageToken(text: ' plan?', gloss: 'plan', isContent: true),
      ],
    );

    final content = tokens.where((token) => token.isContent).toList();
    expect(content.map((token) => token.text), ['Cuál', 'es', 'el', 'plan']);
    expect(content.map((token) => token.gloss), ['What', 'is', 'the', 'plan']);
    expect(content.map((token) => token.romanization), [
      'Cuál',
      'es',
      'el',
      'plan',
    ]);
  });

  test('apostrophes and hyphens stay inside a tappable word', () {
    final tokens = messageTokensForText(
      "L'homme est très bien-aimé.",
      metadata: const [
        MessageToken(text: "L'homme", gloss: 'The man', isContent: true),
        MessageToken(text: ' ', isContent: false),
        MessageToken(text: 'est', gloss: 'is', isContent: true),
        MessageToken(text: ' ', isContent: false),
        MessageToken(text: 'très', gloss: 'very', isContent: true),
        MessageToken(text: ' ', isContent: false),
        MessageToken(text: 'bien-aimé', gloss: 'well-liked', isContent: true),
        MessageToken(text: '.', isContent: false),
      ],
    );

    final content = tokens.where((token) => token.isContent).toList();
    expect(content.map((token) => token.text), [
      "L'homme",
      'est',
      'très',
      'bien-aimé',
    ]);
    expect(content.first.gloss, 'The man');
    expect(content.last.gloss, 'well-liked');
  });
}
