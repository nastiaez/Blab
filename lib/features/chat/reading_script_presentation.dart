import '../../shared/models/message_token.dart';
import '../../shared/models/reading_script.dart';

final _devanagari = RegExp(r'[\u0900-\u097F]');
final _tamil = RegExp(r'[\u0B80-\u0BFF]');

class ReadingScriptPresentation {
  const ReadingScriptPresentation({
    required this.text,
    required this.tokens,
    required this.usedEnglishLetters,
  });

  final String text;
  final List<MessageToken> tokens;
  final bool usedEnglishLetters;
}

ReadingScriptPresentation presentReadingScript({
  required String text,
  required List<MessageToken> tokens,
  required String languageCode,
  required ReadingScript readingScript,
}) {
  ReadingScriptPresentation unchanged() => ReadingScriptPresentation(
    text: text,
    tokens: tokens,
    usedEnglishLetters: false,
  );

  if (readingScript != ReadingScript.englishLetters ||
      (languageCode != 'hi' && languageCode != 'ta')) {
    return unchanged();
  }

  final sanitized = sanitizeMessageTokens(tokens, text);
  if (sanitized.isEmpty) return unchanged();

  final transformed = <MessageToken>[];
  var convertedAny = false;
  for (final token in sanitized) {
    if (!token.isContent || !_containsNativeScript(token.text, languageCode)) {
      transformed.add(token);
      continue;
    }

    final englishLetters = token.romanization?.trim();
    if (englishLetters == null || englishLetters.isEmpty) return unchanged();
    convertedAny = true;
    transformed.add(
      MessageToken(
        text: englishLetters,
        romanization: token.nativeText ?? token.text,
        nativeText: token.nativeText ?? token.text,
        gloss: token.gloss,
      ),
    );
  }

  if (!convertedAny) return unchanged();
  return ReadingScriptPresentation(
    text: transformed.map((token) => token.text).join(),
    tokens: transformed,
    usedEnglishLetters: true,
  );
}

bool _containsNativeScript(String value, String languageCode) =>
    languageCode == 'hi' ? _devanagari.hasMatch(value) : _tamil.hasMatch(value);
