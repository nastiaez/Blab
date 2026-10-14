import 'package:flutter_test/flutter_test.dart';
import 'package:blab/shared/services/chat_service.dart';

void main() {
  final row = <String, dynamic>{
    'message_id': 'message',
    'chat_id': 'chat',
    'viewer_id': 'alice',
    'target_lang': 'de',
    'learning_language': 'de',
    'interface_lang': 'en',
    'language_revision': 3,
    'source_hash': 'source',
    'result': {
      'mode': 'translation',
      'sourceLang': 'en',
      'translation': 'Hallo',
      'interfaceText': 'Hello',
      'explanation': null,
      'confidence': null,
      'formAlternatives': null,
    },
  };
  test('readable result warms both modes without invented word help', () {
    final changes = readableTranslationChanges(row);
    expect(changes.map((change) => change.targetLang), ['de', 'en']);
    expect(changes.map((change) => change.translation.text), [
      'Hallo',
      'Hello',
    ]);
    for (final change in changes) {
      expect(
        change.translation.tokens.any((token) => token.containsKey('text')),
        isFalse,
      );
      expect(change.translation.tokens.single['wordMetadataReady'], isFalse);
    }
  });
  test('readable device package stays source, viewer and era bound', () {
    final package = readablePreparedPackage(row)!;
    expect(package['source_version'], 'source');
    expect(package['viewer_id'], 'alice');
    expect(package['language_revision'], 3);
    expect(package['word_metadata_ready'], isFalse);
  });
  test('known-language-only result cannot fake a prepared practice lane', () {
    expect(readablePreparedPackage({...row, 'target_lang': 'en'}), isNull);
  });
  test('invalid or missing readable text is not displayed', () {
    expect(readableTranslationChanges({...row, 'result': null}), isEmpty);
    expect(
      readablePreparedPackage({
        ...row,
        'result': {'translation': 'Hallo'},
      }),
      isNull,
    );
  });
}
