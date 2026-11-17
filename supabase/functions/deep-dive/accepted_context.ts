import { type Context, DiveError, type DiveRequest } from "./contract.ts";
const record = (x: unknown): x is Record<string, any> =>
  !!x && typeof x === "object" && !Array.isArray(x);

/** Only stored complete variants are accepted; no Cartesian recombination. */
export function acceptedVariants(row: Record<string, any>): string[] {
  const variants = new Set<string>();
  if (typeof row.translation_text === "string" && row.translation_text.length) {
    variants.add(row.translation_text);
  }
  const inputs: unknown[] = [row.form_alternatives];
  if (Array.isArray(row.tokens)) {
    for (const token of row.tokens) {
      if (record(token) && token.formAlternatives != null) {
        inputs.push(token.formAlternatives);
      }
    }
  }
  for (const input of inputs) {
    for (
      const value of Array.isArray(input) ? input : [input]
    ) {
      if (
        !record(value) || typeof value.before !== "string" ||
        typeof value.after !== "string" ||
        typeof value.feminine !== "string" || !value.feminine.trim() ||
        typeof value.masculine !== "string" || !value.masculine.trim() ||
        typeof value.subjectName !== "string" || !value.subjectName.trim() ||
        typeof value.subjectIsViewer !== "boolean"
      ) continue;
      for (const form of [value.feminine, value.masculine]) {
        const text = value.before + form + value.after;
        if (text.length <= 8000) variants.add(text);
      }
    }
  }
  return [...variants];
}

export function historicalEra(
  rows: Record<string, any>[],
  sentAt: string,
  fallbackLanguage: string,
  fallbackRevision: number,
) {
  const sorted = rows.filter((r) =>
    Number.isSafeInteger(r.revision) && r.revision > 0 &&
    typeof r.learning_language === "string"
  ).sort((a, b) => a.revision - b.revision);
  if (!sorted.length) {
    return { language: fallbackLanguage, revision: fallbackRevision };
  }
  let selected = sorted.find((r) => r.revision === 1) ?? sorted[0];
  for (const row of sorted) {
    if (
      row.revision !== 1 && Number.isFinite(Date.parse(row.created_at)) &&
      Date.parse(row.created_at) <= Date.parse(sentAt)
    ) selected = row;
  }
  return {
    language: selected.learning_language as string,
    revision: selected.revision as number,
  };
}

export function acceptedContext(
  r: DiveRequest,
  identity: Omit<Context, "translation" | "tokens" | "sourceLang" | "aidMode">,
  row: Record<string, any>,
  kind: "prepared" | "legacy",
): Context {
  const sourceHash = kind === "prepared" ? row.source_version : row.source_hash;
  const language = kind === "prepared"
    ? row.learning_language
    : row.target_lang;
  const known = kind === "prepared"
    ? row.primary_known_language
    : row.interface_lang;
  if (
    sourceHash !== identity.sourceVersion || language !== identity.targetLang ||
    known !== identity.knownLang ||
    (kind === "prepared" &&
      (row.viewer_id !== identity.viewerId || row.status !== "ready" ||
        row.language_revision !== identity.revision)) ||
    (r.sourceText !== undefined && r.sourceText !== identity.source) ||
    (r.languageRevision !== undefined &&
      r.languageRevision !== identity.revision)
  ) throw new DiveError("stale_context");
  const selected = r.acceptedText ??
    (r.kind === "vocabulary" ? r.text : row.translation_text);
  if (
    typeof selected !== "string" || !acceptedVariants(row).includes(selected)
  ) throw new DiveError("accepted_context_unavailable");
  return {
    ...identity,
    translation: selected,
    baseTranslation: row.translation_text,
    sourceLang: row.source_lang,
    aidMode: row.aid_mode,
    tokens: Array.isArray(row.tokens) ? row.tokens : [],
  };
}
