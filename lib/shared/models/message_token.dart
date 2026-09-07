/// A single tappable (or non-tappable) segment of a message rendered in the
/// target language.
///
/// PRD US-018 / FR-12 — when [isContent] is true the segment is tappable and
/// will surface a word-popup with [romanization] + [gloss] in Step 1.6.
/// Non-content tokens (whitespace, punctuation, emoji) are rendered inline but
/// not tappable.
class MessageToken {
  const MessageToken({
    required this.text,
    this.romanization,
    this.gloss,
    this.isContent = true,
  });

  /// The raw text as it appears in the message (e.g. `எப்படி`).
  final String text;

  /// Latin-script romanization, e.g. `eppadi`. Optional — only present for
  /// scripts the user is unlikely to read (Tamil, Hindi, etc.).
  final String? romanization;

  /// Short definition in the viewer's interface language. Optional.
  final String? gloss;

  /// Whether this token is a "content" word the user can tap. Punctuation,
  /// whitespace and emoji should set this to `false`.
  final bool isContent;
}

final _internalWhitespace = RegExp(r'\s');
final _wordCharacter = RegExp(r'[\p{L}\p{M}\p{N}]', unicode: true);
final _letterCharacter = RegExp(r'\p{L}', unicode: true);
final _markOrNumberCharacter = RegExp(r'[\p{M}\p{N}]', unicode: true);
final _latinLetter = RegExp(r'[A-Za-z\u00C0-\u024F]');
const _wordConnectors = <String>{"'", '’', '-', '‐', '‑'};

/// Word popup tokens are optional metadata. If the provider returns a whole
/// phrase as one content token, discard the token list and keep plain text.
List<MessageToken> sanitizeMessageTokens(
  List<MessageToken> tokens,
  String expectedText,
) {
  if (tokens.isEmpty) return const [];
  final reproduced = StringBuffer();
  for (final token in tokens) {
    reproduced.write(token.text);
    if (!token.isContent) continue;
    if (token.text.trim().isEmpty) return const [];
    if (_internalWhitespace.hasMatch(token.text.trim())) return const [];
  }
  if (reproduced.toString() != expectedText) return const [];
  return tokens;
}

/// Builds stable tap zones from the visible text itself. Provider tokens are
/// treated only as optional enrichment for matching words, never as layout.
List<MessageToken> messageTokensForText(
  String text, {
  List<MessageToken>? metadata,
}) {
  if (text.isEmpty) return const [];
  final displayTokens = _splitVisibleText(text);
  final sanitized = metadata == null
      ? const []
      : sanitizeMessageTokens(metadata, text);
  if (sanitized.isEmpty) return displayTokens;

  final metadataByKey = <String, List<MessageToken>>{};
  for (final token in sanitized.where((t) => t.isContent)) {
    final key = _contentKey(token.text);
    if (key.isEmpty) continue;
    metadataByKey.putIfAbsent(key, () => <MessageToken>[]).add(token);
  }

  return [
    for (final token in displayTokens)
      if (!token.isContent)
        token
      else
        _enrichedToken(token, metadataByKey[_contentKey(token.text)]),
  ];
}

List<MessageToken> _splitVisibleText(String text) {
  final tokens = <MessageToken>[];
  final current = StringBuffer();
  bool? currentIsContent;
  final characters = text.runes.map(String.fromCharCode).toList();

  void flush() {
    if (current.isEmpty) return;
    tokens.add(
      MessageToken(text: current.toString(), isContent: currentIsContent!),
    );
    current.clear();
  }

  for (var index = 0; index < characters.length; index++) {
    final char = characters[index];
    final isConnector = _wordConnectors.contains(char);
    final isContent =
        _wordCharacter.hasMatch(char) ||
        (isConnector &&
            index > 0 &&
            index + 1 < characters.length &&
            _wordCharacter.hasMatch(characters[index - 1]) &&
            _wordCharacter.hasMatch(characters[index + 1]));
    if (currentIsContent != null && currentIsContent != isContent) {
      flush();
    }
    currentIsContent = isContent;
    current.write(char);
  }
  flush();
  return tokens;
}

MessageToken _enrichedToken(
  MessageToken visibleToken,
  List<MessageToken>? candidates,
) {
  if (candidates == null || candidates.isEmpty) return visibleToken;
  final match = candidates.removeAt(0);
  return MessageToken(
    text: visibleToken.text,
    romanization:
        match.romanization ??
        (_usesLatinScript(visibleToken.text) ? visibleToken.text : null),
    gloss: match.gloss,
    isContent: true,
  );
}

String _contentKey(String value) => value.runes
    .map(String.fromCharCode)
    .where(_wordCharacter.hasMatch)
    .join()
    .toLowerCase();

bool _usesLatinScript(String value) {
  var hasLatinLetter = false;
  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    if (_latinLetter.hasMatch(character)) {
      hasLatinLetter = true;
      continue;
    }
    if (_letterCharacter.hasMatch(character)) return false;
    if (_markOrNumberCharacter.hasMatch(character) ||
        _wordConnectors.contains(character)) {
      continue;
    }
  }
  return hasLatinLetter;
}
