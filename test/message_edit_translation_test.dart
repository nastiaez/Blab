import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('whitespace and emoji-only edits preserve translation meaning', () {
    expect(translationMeaningfulText('Hello'), 'Hello');
    expect(translationMeaningfulText('  Hello  👋🏽'), 'Hello');
    expect(translationMeaningfulText('Hello\n❤️'), 'Hello');
  });

  test('letters numbers and punctuation invalidate translation meaning', () {
    expect(translationMeaningfulText('Hello!'), isNot('Hello'));
    expect(translationMeaningfulText('Hello2'), isNot('Hello'));
    expect(translationMeaningfulText('Hallo'), isNot('Hello'));
  });
}
