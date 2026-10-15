import { READABLE_PHASE_RULE } from "./rulebook.ts";
import {
  isProtectedLiteralMessage,
  parseProviderResult,
  TRANSLATION_RESPONSE_FORMAT,
  type TranslationResult,
  type TranslationToken,
  wordGlossMetadataNeedsRepair,
} from "./contract.ts";

// This is an explicit separate contract. Missing metadata is never advertised
// as a completed word-help package or written to the legacy complete cache.
type OutputSchema = {
  properties: Record<string, OutputSchema>;
  required: string[];
};
const schema = structuredClone(TRANSLATION_RESPONSE_FORMAT) as unknown as {
  type: string;
  json_schema: { name: string; strict: boolean; schema: OutputSchema };
};
const properties = schema.json_schema.schema.properties as Record<
  string,
  unknown
>;
delete properties.tokens;
(schema.json_schema.schema as { required: readonly string[] }).required = schema
  .json_schema.schema.required.filter((key) => key !== "tokens");
const forms = properties.formAlternatives as {
  properties: Record<string, unknown>;
  required: readonly string[];
};
delete forms.properties.feminineTokens;
delete forms.properties.masculineTokens;
forms.required = forms.required.filter((key) => !key.endsWith("Tokens"));
schema.json_schema.name = "blab_readable_translation";
export const READABLE_TRANSLATION_RESPONSE_FORMAT = schema;

// Only use for server-owned, source/revision-bound accepted rows. Provider
// parsing deliberately ignores subjectRole; a metadata-only retry must retain
// the role already established by the independent agreement checks.
export function restoreAcceptedReadable(
  saved: unknown,
  source: string,
  target: string,
  known: string,
): TranslationResult | null {
  const result = parseProviderResult(
    JSON.stringify(saved),
    source,
    target,
    known,
    undefined,
    true,
  );
  if (!result || !saved || typeof saved !== "object") return result;
  const forms = (saved as Record<string, unknown>).formAlternatives;
  if (result.formAlternatives && forms && typeof forms === "object") {
    const role = (forms as Record<string, unknown>).subjectRole;
    if (role === "author" || role === "recipient") {
      result.formAlternatives.subjectRole = role;
    }
  }
  return result;
}

export function copiedForeignKnownLane(
  sourceText: string,
  knownText: string,
  sourceLang: string,
  knownLang: string,
): boolean {
  return sourceLang !== knownLang && sourceLang !== "other" &&
    !isProtectedLiteralMessage(sourceText) &&
    /\p{L}/u.test(sourceText) &&
    sourceText.normalize("NFKC").trim().toLocaleLowerCase() ===
      knownText.normalize("NFKC").trim().toLocaleLowerCase();
}

export function knownLaneIsAuthoredOriginal(
  sourceText: string,
  candidate: string,
  sourceLang: string,
  interfaceLang: string,
): boolean {
  // Byte-identical authored text has undergone no meaning-changing rewrite.
  // Changes to spelling, whitespace or punctuation still require review.
  return sourceLang === interfaceLang && sourceText === candidate;
}

export function readableProviderMessages(
  messages: Array<{ role: string; content: string }>,
): Array<{ role: string; content: string }> {
  const instruction = READABLE_PHASE_RULE;
  return messages.map((message, index) =>
    index === 0
      ? { ...message, content: message.content + instruction }
      : message
  );
}

export async function enrichAcceptedWordHelp(
  accepted: TranslationResult,
  prepare: (
    sentence: string,
    knownSentence: string,
  ) => Promise<TranslationToken[] | null>,
  targetLang: string,
  interfaceLang: string,
  sourceText: string,
): Promise<TranslationResult | null> {
  if (
    accepted.sourceLang === "other" || isProtectedLiteralMessage(sourceText)
  ) return accepted;
  const forms = accepted.formAlternatives;
  const sentences = [
    accepted.translation,
    ...(forms
      ? [
        `${forms.before}${forms.feminine}${forms.after}`,
        `${forms.before}${forms.masculine}${forms.after}`,
      ]
      : []),
  ];
  // Equal base/feminine sentences share one metadata call. Metadata never
  // rewrites the accepted sentence or re-enters the translation pipeline.
  const unique = [...new Set(sentences)];
  const prepared = await Promise.all(
    unique.map((sentence) => prepare(sentence, accepted.interfaceText)),
  );
  if (prepared.some((tokens) => tokens === null)) return null;
  const tokensByText = new Map(
    unique.map((sentence, index) => [sentence, prepared[index]!]),
  );
  const enriched = {
    ...accepted,
    tokens: tokensByText.get(accepted.translation)!,
  };
  if (
    wordGlossMetadataNeedsRepair(
      enriched,
      targetLang,
      interfaceLang,
      sourceText,
    )
  ) return null;
  if (forms) {
    for (const sentence of sentences.slice(1)) {
      if (
        wordGlossMetadataNeedsRepair(
          {
            ...accepted,
            translation: sentence,
            tokens: tokensByText.get(sentence)!,
          },
          targetLang,
          interfaceLang,
          sourceText,
        )
      ) return null;
    }
    enriched.formAlternatives = {
      ...forms,
      feminineTokens: tokensByText.get(sentences[1])!,
      masculineTokens: tokensByText.get(sentences[2])!,
    };
  }
  return enriched;
}

// Readable-first is the normal delivery contract; false is an explicit rollback.
export function textFirstDeliveryEnabled(value: string | undefined): boolean {
  return value?.trim().toLowerCase() !== "false";
}
