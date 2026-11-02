import { type Mention, parseMentions } from "../stream-message/mentions.ts";

// The provider sees opaque handles, never account IDs.
export function protectMentions(text: string, raw: unknown) {
  const mentions = parseMentions(raw, text);
  let nonce: string;
  do {
    nonce = crypto.randomUUID().replaceAll("-", "").slice(0, 12);
  } while (text.includes(nonce));
  const handles = mentions.map((_, i) => `@blab_${nonce}_${i}`);
  let protectedText = text;
  for (let i = mentions.length - 1; i >= 0; i--) {
    const m = mentions[i];
    protectedText = protectedText.slice(0, m.start) + handles[i] +
      protectedText.slice(m.start + m.label.length + 1);
  }
  return { text: protectedText, mentions, handles };
}

const identifiers = (text: string, handles: string[]) => {
  // Only trusted IDs may end before morphology. Unknown/authored reserved
  // literals retain their entire original spelling and multiplicity checks.
  // ASCII identifier continuations (including hyphenated ones) are ambiguous,
  // so never accept a trusted ID as a substring of an extended identifier.
  return Array.from(
    text.matchAll(/(?<![\p{L}\p{N}_.+%\-])@[\p{L}\p{M}\p{N}_-]+/gu),
    (match) => {
      const literal = match[0];
      const handle = handles.find((h) => {
        if (!literal.startsWith(h)) return false;
        const suffix = literal.slice(h.length);
        return !/^(?:[A-Za-z0-9_]|-[A-Za-z0-9_])/.test(suffix);
      });
      return handle ?? literal;
    },
  );
};
export function restoreMentionText(
  text: string,
  protectedData: ReturnType<typeof protectMentions>,
  requireAll = true,
) {
  // Compare all @identifiers before restoration so authored literal handles
  // remain ordinary text. Only the exact trusted identity span is restored.
  const counts = new Map<string, number>();
  for (const id of identifiers(text, protectedData.handles)) {
    counts.set(id, (counts.get(id) ?? 0) + 1);
  }
  const allowed = new Map<string, number>();
  for (const id of identifiers(protectedData.text, protectedData.handles)) {
    if (!protectedData.handles.includes(id)) {
      allowed.set(id, (allowed.get(id) ?? 0) + 1);
    }
  }
  for (const [id, count] of counts) {
    if (protectedData.handles.includes(id)) {
      if (count > 1) throw new Error("mention_identity_duplicated");
    } else if (count > (allowed.get(id) ?? 0)) {
      throw new Error("unknown_mention_handle");
    }
  }
  if (requireAll) {
    for (const [id, count] of allowed) {
      if ((counts.get(id) ?? 0) !== count) {
        throw new Error("authored_handle_changed");
      }
    }
  }
  let restored = "", cursor = 0;
  const ranges: Mention[] = [];
  const occurrences = protectedData.handles.flatMap((handle, index) => {
    const count = counts.get(handle) ?? 0;
    if (requireAll && count !== 1) throw new Error("mention_identity_lost");
    if (!count) return [];
    const start = text.indexOf(handle);
    return [{ index, start, end: start + handle.length }];
  }).sort((a, b) => a.start - b.start);
  for (const hit of occurrences) {
    restored += text.slice(cursor, hit.start);
    const m = protectedData.mentions[hit.index];
    ranges.push({ ...m, start: restored.length });
    restored += "@" + m.label;
    cursor = hit.end;
  }
  restored += text.slice(cursor);
  return { text: restored, mentions: ranges };
}

/** Sentence identity is mandatory; optional enrichment degrades independently. */
export function restoreMentionResult<T>(
  result: T,
  data: ReturnType<typeof protectMentions>,
): T {
  const r = result as Record<string, any>;
  const spans: Record<string, Mention[]> = {};
  const sentence = (text: string) => {
    const restored = restoreMentionText(text, data);
    if (restored.mentions.length) spans[restored.text] = restored.mentions;
    return restored.text;
  };
  const walk = (value: any): any => {
    if (typeof value === "string") {
      const restored = restoreMentionText(value, data, false);
      if (data.handles.some((h) => restored.text.includes(h.split("_")[1]))) {
        throw new Error("split_mention_handle");
      }
      return restored.text;
    }
    if (Array.isArray(value)) return value.map(walk);
    if (value && typeof value === "object") {
      return Object.fromEntries(
        Object.entries(value).map(([k, v]) => [k, walk(v)]),
      );
    }
    return value;
  };
  const optional = (value: any, fallback: any) => {
    try {
      return walk(value);
    } catch {
      return fallback;
    }
  };
  const output = { ...r };
  for (const key of ["translation", "interfaceText"]) {
    if (typeof r[key] === "string") output[key] = sentence(r[key]);
  }
  output.explanation = optional(r.explanation, null);
  output.tokens = optional(r.tokens, []);
  if (
    !Array.isArray(output.tokens) ||
    output.tokens.map((t: any) => typeof t?.text === "string" ? t.text : "")
        .join("") !== output.translation
  ) output.tokens = [];
  output.formAlternatives = null;
  if (r.formAlternatives) {
    try {
      const f = r.formAlternatives;
      for (const gender of ["feminine", "masculine"]) {
        sentence(f.before + f[gender] + f.after);
      }
      const { feminineTokens, masculineTokens, ...fields } = f;
      output.formAlternatives = {
        ...walk(fields),
        feminineTokens: optional(feminineTokens, []),
        masculineTokens: optional(masculineTokens, []),
      };
      for (const gender of ["feminine", "masculine"]) {
        const key = gender + "Tokens";
        const tokens = output.formAlternatives[key];
        const expected = output.formAlternatives.before +
          output.formAlternatives[gender] + output.formAlternatives.after;
        if (
          !Array.isArray(tokens) ||
          tokens.map((t: any) => typeof t?.text === "string" ? t.text : "")
              .join("") !== expected
        ) {
          output.formAlternatives[key] = [];
        }
      }
    } catch { /* Invalid optional forms cannot discard a valid sentence. */ }
  }
  if (data.mentions.length) {
    output.tokens.push({
      blabMentionSpans: spans,
      blabMentionSource: data.mentions,
    });
  }
  return output as T;
}

// Explicit codes only: unrelated transport/format failures keep their retry policy.
export function isMentionIntegrityFailure(error: unknown): boolean {
  const reason = error instanceof Error ? error.message : error;
  return typeof reason === "string" && [
    "mention_identity_duplicated",
    "unknown_mention_handle",
    "authored_handle_changed",
    "mention_identity_lost",
    "split_mention_handle",
  ].includes(reason);
}
