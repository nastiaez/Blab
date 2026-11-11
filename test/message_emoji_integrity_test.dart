import 'package:blab/shared/models/message_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final emoji in ['📍', '🎟️', '👩🏽‍💻', '🇺🇦', '❤️', '1️⃣']) {
    test('message display keeps $emoji within one token', () {
      final text = 'Hello $emoji world';
      final tokens = messageTokensForText(text);
      expect(tokens.map((t) => t.text).join(), text);
      expect(tokens.any((t) => t.text.contains(emoji)), isTrue);
      expect(
        tokens.where((t) => t.text.contains(emoji)).single.isContent,
        isFalse,
      );
    });
  }
}
