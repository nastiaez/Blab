// US-042 / FR-34. Keep aligned with participant_form_relevance.dart.
export function hasParticipantFormDifference(
  targetLanguage: string,
  feminine: string,
  masculine: string,
): boolean {
  if (feminine.trim() === masculine.trim()) return false;
  if (targetLanguage !== "de") return true;
  const withoutNounDeclension = (text: string) =>
    text.replace(
      /\b(mein|dein|sein|ihr|unser|euer|eur|dies|jen|welch|solch|ein|kein)(?:e|en|em|er|es)?\b/gi,
      (match: string, stem: string, offset: number) => {
        if (
          !/^\s+[A-ZÄÖÜ][a-zäöüß]+\b/.test(text.slice(offset + match.length))
        ) {
          return match;
        }
        return stem.toLowerCase() === "eur" ? "euer" : stem.toLowerCase();
      },
    ).toLowerCase();
  return withoutNounDeclension(feminine) !== withoutNounDeclension(masculine);
}
