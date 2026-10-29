import { type Mention, parseMentions } from "../stream-message/mentions.ts";

// The provider sees opaque handles, never account IDs. Reconstitute readable
// text and a trusted offset sidecar BEFORE persistence or delivery to old apps.
export function protectMentions(text: string, raw: unknown) {
  const mentions = parseMentions(raw, text);
  const nonce = crypto.randomUUID().replaceAll("-", "").slice(0, 12);
  const handles = mentions.map((_, i) => `@blab_${nonce}_${i}`);
  let protectedText = text;
  for (let i = mentions.length - 1; i >= 0; i--) {
    const m = mentions[i];
    protectedText = protectedText.slice(0, m.start) + handles[i] +
      protectedText.slice(m.start + m.label.length + 1);
  }
  return { text: protectedText, mentions, handles };
}

export function restoreMentionText(
  text: string,
  protectedData: ReturnType<typeof protectMentions>,
  requireAll = true,
) {
  let restored = "", cursor = 0;
  const ranges: Mention[] = [];
  const occurrences = protectedData.handles.flatMap((handle, index) => {
    const hits: Array<{ index: number; start: number; end: number }> = [];
    let start = text.indexOf(handle);
    while (start >= 0) {
      hits.push({ index, start, end: start + handle.length });
      start = text.indexOf(handle, start + handle.length);
    }
    if (requireAll && hits.length !== 1) {
      throw new Error("mention_identity_lost");
    }
    if (hits.length > 1) throw new Error("mention_identity_duplicated");
    return hits;
  }).sort((a, b) => a.start - b.start);
  for (const hit of occurrences) {
    restored += text.slice(cursor, hit.start);
    const m = protectedData.mentions[hit.index];
    ranges.push({ ...m, start: restored.length });
    restored += "@" + m.label;
    cursor = hit.end;
  }
  restored += text.slice(cursor);
  if (/@blab_[0-9a-f]{12}_\d+/.test(restored)) {
    throw new Error("unknown_mention_handle");
  }
  return { text: restored, mentions: ranges };
}

/** Restore strings recursively; sidecar maps each complete sentence to ranges. */
export function restoreMentionResult<T>(
  result: T,
  data: ReturnType<typeof protectMentions>,
): T {
  if (!data.mentions.length) return result;
  const spans: Record<string, Mention[]> = {};
  const walk = (value: unknown): unknown => {
    if (typeof value === "string") {
      const r = restoreMentionText(value, data, false);
      if (r.mentions.length) spans[r.text] = r.mentions;
      return r.text;
    }
    if (Array.isArray(value)) return value.map(walk);
    if (value && typeof value === "object") {
      return Object.fromEntries(
        Object.entries(value).map(([k, v]) => [k, walk(v)]),
      );
    }
    return value;
  };
  const r = result as Record<string, unknown>;
  for (const key of ["translation", "interfaceText"]) {
    if (typeof r[key] === "string") restoreMentionText(r[key] as string, data);
  }
  const output = walk(result) as Record<string, unknown>;
  const forms = r.formAlternatives as Record<string, string> | null;
  if (forms) {
    for (const gender of ["feminine", "masculine"]) {
      const form = restoreMentionText(
        forms.before + forms[gender] + forms.after,
        data,
      );
      spans[form.text] = form.mentions;
    }
  }
  let tokens = Array.isArray(output.tokens) ? output.tokens : [];
  if (tokens.map((t: any) => typeof t?.text === 'string' ? t.text : '').join('') !== output.translation) tokens = [];
  // Tokenization may split a protected handle. Optional word help must not leak
  // a partial internal handle, nor make the accepted sentence disappear.
  const nonce = data.handles[0]?.split('_')[1];
  if (nonce && JSON.stringify(tokens).includes(nonce)) tokens = [];
  const outputForms = output.formAlternatives as Record<string,unknown> | null;
  if (outputForms) {
    for (const key of ['feminineTokens','masculineTokens']) {
      if (nonce && JSON.stringify(outputForms[key]).includes(nonce)) outputForms[key] = [];
    }
  }
  output.tokens = [...tokens, { blabMentionSpans: spans }];
  return output as T;
}
