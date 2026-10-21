import {
  generateGroupOutputs,
  groupVariantKey,
  privateGroupResult,
} from "./group_outputs.ts";
import {
  type PreparedViewer,
  singleCallRequest,
} from "../translate-message/single_call.ts";
import type { TranslationResult } from "../translate-message/contract.ts";

const assert = (ok: unknown, why: string) => {
  if (!ok) throw Error(why);
};
const viewer = (key: string): PreparedViewer => ({
  key,
  messageId: "message",
  sourceHash: "source",
  text: "Hello everyone!",
  targetLang: "de",
  interfaceLang: "en",
  context: [],
  formContext: {
    group: true,
    messageAuthor: "partner",
    viewerName: "group",
    partnerName: "Alice",
    tone: "informal",
  },
});
const output = (): TranslationResult => ({
  mode: "translation",
  sourceLang: "en",
  translation: "Hallo zusammen!",
  interfaceText: "Hello everyone!",
  tokens: [],
  explanation: null,
  confidence: null,
  formAlternatives: null,
});

function recorded() {
  const cache = new Map<string, TranslationResult>();
  const requests: PreparedViewer[][] = [];
  return {
    cache,
    requests,
    hooks: {
      cached: async (_v: PreparedViewer, key: string) => cache.get(key) ?? null,
      save: async (
        _v: PreparedViewer,
        key: string,
        value: TranslationResult,
      ) => {
        cache.set(key, value);
      },
      renew: async () => {},
      generate: async (vs: PreparedViewer[]) => {
        requests.push(vs);
        // Exercise the real compact request planner, not merely the call counter.
        singleCallRequest(vs);
        return Object.fromEntries(vs.map((v) => [v.key, output()]));
      },
    },
  };
}

for (const count of [2, 5, 30, 100]) {
  Deno.test(`${count} identical group viewers share one generation; restart costs zero`, async () => {
    const rec = recorded();
    const viewers = Array.from({ length: count }, (_, i) => viewer(`v${i}`));
    const result = await generateGroupOutputs(viewers, rec.hooks);
    assert(Object.keys(result).length === count, "missing private bindings");
    assert(
      rec.requests.length === 1 && rec.requests[0].length === 1,
      "per-person generation fanout",
    );
    await generateGroupOutputs(viewers, {
      ...rec.hooks,
      generate: async () => {
        throw Error("cache restarted provider");
      },
    });
    result.v0.translation = "changed";
    assert(result.v1.translation !== "changed", "viewer result object shared");
  });
}

Deno.test("author and many different recipients fit one group request, with private corrections", async () => {
  const rec = recorded();
  const author = viewer("author");
  author.formContext = {
    group: true,
    messageAuthor: "viewer",
    viewerName: "Alice",
    partnerName: "group",
    tone: "informal",
  };
  const viewers = [
    author,
    ...Array.from({ length: 99 }, (_, i) => viewer(`recipient${i}`)),
  ];
  const correction = {
    ...output(),
    mode: "correction" as const,
    translation: "Private corrected sentence",
    explanation: "Private explanation",
    confidence: "high" as const,
  };
  const result = await generateGroupOutputs(viewers, {
    ...rec.hooks,
    generate: async (vs) => {
      rec.requests.push(vs);
      singleCallRequest(vs);
      return Object.fromEntries(vs.map((v) => [v.key, correction]));
    },
  });
  assert(
    rec.requests.length === 1 && rec.requests[0].length === 2,
    "author not batched with recipients",
  );
  assert(
    result.author.explanation === "Private explanation",
    "author correction lost",
  );
  assert(
    result.recipient0.translation === viewers[1].text &&
      result.recipient0.explanation === null &&
      result.recipient0.confidence === null,
    "private correction leaked",
  );
  assert(
    await groupVariantKey(author) !== await groupVariantKey(viewers[1]),
    "author artifact reused for recipient",
  );
});

Deno.test("distinct targets, known languages, tones and context never merge incorrectly", async () => {
  const rec = recorded();
  const a = viewer("a");
  const vs = [a, { ...viewer("b"), targetLang: "uk" }, {
    ...viewer("c"),
    interfaceLang: "uk",
  }, {
    ...viewer("d"),
    formContext: { ...(a.formContext as object), tone: "respectful" },
  }, {
    ...viewer("e"),
    context: [{
      speaker: "partner",
      speakerName: "Carol",
      text: "Earlier context",
    }],
  }];
  await generateGroupOutputs(vs, rec.hooks);
  assert(
    rec.cache.size === 5 && rec.requests.length === 2,
    "distinct variant lost or unbounded request",
  );
  assert(rec.requests.every((r) => r.length <= 4), "oversized generation");
});

Deno.test("long distinct outputs split before exhausting the output budget", async () => {
  const rec = recorded();
  const a = { ...viewer("a"), text: "x".repeat(2000) };
  const b = { ...a, key: "b", targetLang: "uk" };
  await generateGroupOutputs([a, b], rec.hooks);
  assert(rec.requests.length === 2, "long output sets not bounded");
});

Deno.test("completed artifact survives a later batch failure and is not regenerated", async () => {
  const rec = recorded();
  const vs = ["de", "uk", "es", "fr", "it"].map((targetLang, i) => ({
    ...viewer(`v${i}`),
    targetLang,
  }));
  let batches = 0;
  try {
    await generateGroupOutputs(vs, {
      ...rec.hooks,
      generate: async (v) => {
        if (++batches === 2) throw Error("provider_interrupted");
        return rec.hooks.generate(v);
      },
    });
  } catch (e) {
    assert(String(e).includes("provider_interrupted"), "wrong failure");
  }
  assert(rec.cache.size === 4, "successful artifacts lost");
  const before = rec.requests.length;
  await generateGroupOutputs(vs, rec.hooks);
  assert(
    rec.requests.length === before + 1 && rec.requests.at(-1)!.length === 1,
    "successful variants regenerated",
  );
});

Deno.test("group recipient form alternatives are never attributed to an arbitrary member", () => {
  const raw = {
    ...output(),
    formAlternatives: {
      subjectRole: "recipient",
    } as TranslationResult["formAlternatives"],
  };
  assert(
    privateGroupResult(viewer("v"), raw).formAlternatives === null,
    "invented group recipient form",
  );
});

Deno.test("large distinct-output groups continue without spending failure attempts", async () => {
  const rec = recorded();
  const viewers = Array.from(
    { length: 20 },
    (_, i) => ({
      ...viewer(`v${i}`),
      text: "x".repeat(2000),
      context: [{
        speaker: "partner",
        speakerName: "Carol",
        text: `Different eligible context ${i}`,
      }],
    }),
  );
  let deferred = 0;
  let result: Record<string, TranslationResult> = {};
  for (let turn = 0; turn < 5; turn++) {
    const before = rec.requests.length;
    result = await generateGroupOutputs(viewers, {
      ...rec.hooks,
      defer: async (vs) => {
        deferred += vs.length;
      },
    });
    assert(
      rec.requests.length - before <= 4,
      "worker exceeded safe generation budget",
    );
  }
  assert(
    deferred > 0 && Object.keys(result).length === 20,
    "continuation lost viewers",
  );
  const keys = rec.requests.flatMap((batch) => batch.map((v) => v.key));
  assert(
    keys.length === 20 && new Set(keys).size === 20,
    "continuation regenerated accepted outputs",
  );
});
