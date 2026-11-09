/** Exclude protected literals inside ordinary prose. */
export function protectedCorrectionOverlap(
  text: string,
  start: number,
  end: number,
): boolean {
  const literals =
    /https?:\/\/[^\s<>]+|www\.[^\s<>]+|[@#][\p{L}\p{M}\p{N}_-]+|\x60[^\x60]*\x60/gu;
  return Array.from(text.matchAll(literals)).some((m) =>
    start < m.index! + m[0].length && end > m.index!
  );
}
export type AuthoredCorrection = {
  original: string;
  occurrence: number;
  replacement: string;
  start: number;
  end: number;
  targetAnchor?: {
    text: string;
    occurrence: number;
    start: number;
    end: number;
  } | null;
};
export function explicitCorrections(
  source: string,
  raw: unknown,
): AuthoredCorrection[] {
  if (!Array.isArray(raw)) return [];
  const spans: AuthoredCorrection[] = [];
  for (const c of raw) {
    if (
      !c || typeof c.original !== "string" || !c.original ||
      typeof c.replacement !== "string" || !Number.isInteger(c.occurrence) ||
      c.occurrence < 0
    ) return [];
    let start = -1, cursor = 0;
    for (let n = 0; n <= c.occurrence; n++) {
      start = source.indexOf(c.original, cursor);
      if (start < 0) return [];
      cursor = start + c.original.length;
    }
    const end = start + c.original.length;
    const splitsSurrogate = (i: number) =>
      i > 0 && i < source.length && /[\uD800-\uDBFF]/.test(source[i - 1]) &&
      /[\uDC00-\uDFFF]/.test(source[i]);
    if (
      protectedCorrectionOverlap(source, start, end) ||
      splitsSurrogate(start) || splitsSurrogate(end) ||
      spans.some((s) => start < s.end && end > s.start)
    ) return [];
    const mechanical = (text: string) =>
      text.toLowerCase().replace(/[\s\p{P}\p{S}]/gu, "");
    if (mechanical(c.original) === mechanical(c.replacement)) continue;
    spans.push({
      original: c.original,
      occurrence: c.occurrence,
      replacement: c.replacement,
      start,
      end,
    });
  }
  return spans.sort((a, b) => a.start - b.start);
}
export function correctedSource(
  source: string,
  spans: AuthoredCorrection[],
): string {
  let text = source;
  for (const c of [...spans].reverse()) {
    text = text.slice(0, c.start) + c.replacement + text.slice(c.end);
  }
  return text;
}

/** Keep generation identity independent of optional token JSON. */
export function serializeGeneration<T extends Record<string, any>>(
  result: T,
): T {
  if (!Object.hasOwn(result, "generationEnvelope")) return result;
  const raw = result.generationEnvelope;
  const envelope =
    raw !== null && typeof raw === "object" && !Array.isArray(raw) ? raw : {};
  return {
    ...result,
    formAlternatives: {
      ...result.formAlternatives,
      blabGenerationEnvelope: envelope,
    },
  };
}

/** Optional alignment never changes or rejects the complete sentence. */
export function anchoredCorrections(
  target: string,
  spans: AuthoredCorrection[],
  raw: unknown,
  source?: string,
): AuthoredCorrection[] {
  const inputs = Array.isArray(raw) ? raw : [];
  const originalAnchors: Array<{ start: number; end: number }> = [];
  const resolved = spans.map((c) => {
    const a = inputs.find((x) =>
      x?.original === c.original && x?.occurrence === c.occurrence
    )?.targetAnchor;
    let anchor: AuthoredCorrection["targetAnchor"] = null;
    if (
      a && typeof a.text === "string" && a.text.length &&
      Number.isSafeInteger(a.occurrence) && a.occurrence >= 0 &&
      a.occurrence <= target.length
    ) {
      let start = -1, cursor = 0;
      for (let n = 0; n <= a.occurrence; n++) {
        start = target.indexOf(a.text, cursor);
        if (start < 0) break;
        cursor = start + a.text.length;
      }
      const split = (i: number) =>
        i > 0 && i < target.length && /[\uD800-\uDBFF]/.test(target[i - 1]) &&
        /[\uDC00-\uDFFF]/.test(target[i]);
      if (
        start >= 0 && !protectedCorrectionOverlap(target, start, cursor) &&
        !split(start) && !split(cursor)
      ) {
        anchor = { text: a.text, occurrence: a.occurrence, start, end: cursor };
      }
    }
    if (anchor) originalAnchors.push(anchor);
    const resolved = { ...c, targetAnchor: anchor };
    if (
      source === undefined || !anchor || anchor.text !== c.replacement ||
      source.slice(c.start, c.end) !== c.original
    ) return resolved;
    const [prefix, suffix] = identicalWholeWordEdges(c.original, c.replacement);
    if (!prefix && !suffix) return resolved;
    const original = c.original.slice(prefix, c.original.length - suffix);
    const replacement = c.replacement.slice(
      prefix,
      c.replacement.length - suffix,
    );
    const start = c.start + prefix, end = c.end - suffix;
    const targetStart = anchor.start + prefix, targetEnd = anchor.end - suffix;
    const occurrence = occurrenceAt(source, original, start);
    const targetOccurrence = occurrenceAt(target, replacement, targetStart);
    if (
      occurrence < 0 || targetOccurrence < 0 ||
      protectedCorrectionOverlap(source, start, end) ||
      protectedCorrectionOverlap(target, targetStart, targetEnd)
    ) return resolved;
    return {
      original,
      replacement,
      occurrence,
      start,
      end,
      targetAnchor: {
        text: replacement,
        occurrence: targetOccurrence,
        start: targetStart,
        end: targetEnd,
      },
    };
  });
  if (
    originalAnchors.some((a, i) =>
      originalAnchors.some((b, j) =>
        i !== j && a.start < b.end && a.end > b.start
      )
    )
  ) return resolved.map((c) => ({ ...c, targetAnchor: null }));
  const anchors = resolved.filter((c) => c.targetAnchor !== null);
  if (
    anchors.some((c, i) =>
      anchors.some((d, j) =>
        i !== j && c.targetAnchor!.start < d.targetAnchor!.end &&
        c.targetAnchor!.end > d.targetAnchor!.start
      )
    )
  ) return resolved.map((c) => ({ ...c, targetAnchor: null }));
  return resolved;
}

/** Exact whitespace-delimited words only: never strip part of an inflection. */
export function identicalWholeWordEdges(
  original: string,
  replacement: string,
): [number, number] {
  let prefix = 0, suffix = 0;
  while (true) {
    const a = original.slice(prefix).match(/^\S+\s+/u)?.[0];
    const b = replacement.slice(prefix).match(/^\S+\s+/u)?.[0];
    if (
      !a || a !== b || prefix + a.length >= original.length ||
      prefix + a.length >= replacement.length
    ) break;
    prefix += a.length;
  }
  while (true) {
    const a = original.slice(prefix, original.length - suffix).match(/\s+\S+$/u)
      ?.[0];
    const b = replacement.slice(prefix, replacement.length - suffix).match(
      /\s+\S+$/u,
    )?.[0];
    if (
      !a || a !== b || prefix + suffix + a.length >= original.length ||
      prefix + suffix + a.length >= replacement.length
    ) break;
    suffix += a.length;
  }
  return [prefix, suffix];
}
function occurrenceAt(text: string, part: string, start: number): number {
  if (!part) return -1;
  let cursor = 0;
  for (let n = 0; cursor <= start; n++) {
    const found = text.indexOf(part, cursor);
    if (found === start) return n;
    if (found < 0 || found > start) return -1;
    cursor = found + part.length;
  }
  return -1;
}
