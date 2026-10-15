// US-042 / FR-34. Keep aligned with translate-message/participant_forms.ts.
bool hasParticipantFormDifference({
  required String targetLanguage,
  required String feminine,
  required String masculine,
}) {
  if (feminine.trim() == masculine.trim()) return false;
  if (targetLanguage != 'de') return true;

  final determiners = RegExp(
    r'\b(mein|dein|sein|ihr|unser|euer|eur|dies|jen|welch|solch|ein|kein)(?:e|en|em|er|es)?\b',
    caseSensitive: false,
  );
  final followingNoun = RegExp(r'^\s+[A-ZÄÖÜ][a-zäöüß]+\b');
  String withoutNounDeclension(String text) =>
      text.replaceAllMapped(determiners, (match) {
        if (!followingNoun.hasMatch(text.substring(match.end))) {
          return match[0]!;
        }
        return switch (match[1]!.toLowerCase()) {
          'eur' => 'euer',
          final stem => stem,
        };
      }).toLowerCase();
  return withoutNounDeclension(feminine) != withoutNounDeclension(masculine);
}
