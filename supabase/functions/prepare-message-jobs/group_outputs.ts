import {
  type PreparedViewer,
  singleCallRequest,
} from "../translate-message/single_call.ts";
import type { TranslationResult } from "../translate-message/contract.ts";
import { SINGLE_CALL_POLICY } from "../translate-message/rulebook.ts";

export const isGroupViewer = (v: PreparedViewer) =>
  (v.formContext as Record<string, unknown> | undefined)?.group === true;

export async function groupVariantKey(v: PreparedViewer): Promise<string> {
  const f = v.formContext as Record<string, unknown>;
  const data = JSON.stringify({
    message: v.messageId,
    source: v.sourceHash,
    mentions: v.mentions ?? [],
    contract: SINGLE_CALL_POLICY.contractVersion,
    author: f.messageAuthor === "viewer",
    request: singleCallRequest([v]),
  });
  return [
    ...new Uint8Array(
      await crypto.subtle.digest("SHA-256", new TextEncoder().encode(data)),
    ),
  ]
    .map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function privateGroupResult(
  v: PreparedViewer,
  raw: TranslationResult,
): TranslationResult {
  const f = v.formContext as Record<string, unknown>;
  const result = structuredClone(raw);
  if (f.messageAuthor !== "viewer") {
    result.explanation = null;
    result.confidence = null;
    if (result.mode === "correction") {
      result.mode = "none";
      result.translation = v.text;
      result.tokens = Array.isArray(v.mentions) && v.mentions.length ? [{blabMentionSource: v.mentions, blabMentionSpans: {
        [v.text]: v.mentions,
        ...Object.assign({}, ...raw.tokens.filter((t: any) => t.blabMentionSpans).map((t: any) => t.blabMentionSpans)),
      }}] as any : [];
    }
  }
  // A group is not a single gendered recipient. Author alternatives remain valid.
  if (result.formAlternatives?.subjectRole === "recipient") {
    result.formAlternatives = null;
  }
  return result;
}

type Hooks = {
  generate: (
    viewers: PreparedViewer[],
  ) => Promise<Record<string, TranslationResult>>;
  cached: (
    viewer: PreparedViewer,
    key: string,
  ) => Promise<TranslationResult | null>;
  save: (
    viewer: PreparedViewer,
    key: string,
    result: TranslationResult,
  ) => Promise<void>;
  renew: () => Promise<void>;
  defer?: (viewers: PreparedViewer[]) => Promise<void>;
};

/** One generation per distinct output contract, with private viewer bindings. */
export async function generateGroupOutputs(
  viewers: PreparedViewer[],
  hooks: Hooks,
) {
  const groups = new Map<string, PreparedViewer[]>();
  for (const v of viewers) {
    const key = await groupVariantKey(v);
    groups.set(key, [...(groups.get(key) ?? []), v]);
  }
  const results: Record<string, TranslationResult> = {};
  const missing: Array<{ key: string; viewers: PreparedViewer[] }> = [];
  const bind = (vs: PreparedViewer[], result: TranslationResult) => {
    for (const v of vs) results[v.key] = structuredClone(result);
  };
  for (const [key, vs] of groups) {
    const cached = await hooks.cached(vs[0], key);
    if (cached) bind(vs, privateGroupResult(vs[0], cached));
    else missing.push({ key, viewers: vs });
  }
  // Same four-contract bound as 1:1 generation; 100 identical members still
  // occupy one representative, not 25 duplicate four-person requests.
  let i = 0;
  let generations = 0;
  for (; i < missing.length && generations < 4;) {
    await hooks.renew();
    const batch: typeof missing = [];
    let estimatedTokens = 0;
    while (i < missing.length && batch.length < 4) {
      const cost = Math.max(2500, missing[i].viewers[0].text.length * 12);
      if (
        batch.length &&
        estimatedTokens + cost > SINGLE_CALL_POLICY.maxOutputTokens
      ) break;
      batch.push(missing[i++]);
      estimatedTokens += cost;
    }
    const generated = await hooks.generate(batch.map((g) => g.viewers[0]));
    generations++;
    for (const g of batch) {
      const raw = generated[g.viewers[0].key];
      if (!raw) continue;
      const result = privateGroupResult(g.viewers[0], raw);
      await hooks.save(g.viewers[0], g.key, result);
      bind(g.viewers, result);
    }
  }
  if (i < missing.length) {
    if (!hooks.defer) throw new Error("group_generation_budget_exhausted");
    await hooks.defer(missing.slice(i).flatMap((g) => g.viewers));
  }
  return results;
}
