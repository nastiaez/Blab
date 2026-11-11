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

/** Cached provenance is independent of optional grammatical choices. */
export function cachedFormAlternatives(
  raw: unknown,
  target: string,
  mode: unknown,
): unknown {
  if (Array.isArray(raw)) {
    const valid = raw.map((item) => cachedFormAlternatives(item, target, mode))
      .filter((item) => item !== null);
    return valid.length ? valid : null;
  }
  if (raw === null || typeof raw !== "object") return null;
  const value = raw as Record<string, unknown>;
  const hasEnvelope = Object.hasOwn(value, "blabGenerationEnvelope");
  const valid = mode === "translation" &&
    ["before", "feminine", "masculine", "after"].every((key) =>
      typeof value[key] === "string"
    ) &&
    hasParticipantFormDifference(
      target,
      String(value.before) + String(value.feminine) + String(value.after),
      String(value.before) + String(value.masculine) + String(value.after),
    );
  if (valid) return value;
  return hasEnvelope
    ? { blabGenerationEnvelope: value.blabGenerationEnvelope }
    : null;
}
