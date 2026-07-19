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
