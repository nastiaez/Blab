import { dispatchGuard } from "./qa_budget.ts";
import { fetchChatCompletion } from "../translate-message/provider.ts";
import type { ProviderCredential } from "../translate-message/contract.ts";
function assert(v: unknown) {
  if (!v) throw Error("assert");
}
const credential = (): ProviderCredential => ({
  provider: "openai",
  apiKey: "synthetic",
  model: "gpt-6-luna",
  useOpenRouterProviderPolicy: false,
});
Deno.test("QA atomic dispatch CAS prevents parallel or repeated fallback dispatch", async () => {
  let consumed = false, calls = 0;
  const c = credential();
  c.dispatchGuard = dispatchGuard(
    async () => {
      if (consumed) return { data: false, error: null };
      consumed = true;
      return { data: true, error: null };
    },
    { p_kind: "base" },
    true,
  );
  const run = () =>
    fetchChatCompletion(c, { messages: [], max_tokens: 2500 }, {
      fetchImpl: async () => {
        calls++;
        return new Response("{}", {
          headers: { "content-type": "application/json" },
        });
      },
      onMetric: () => {},
    });
  const results = await Promise.allSettled([run(), run(), run()]);
  assert(calls === 1);
  assert(results.filter((r) => r.status === "fulfilled").length === 1);
});
Deno.test("QA final serialized bytes, model and output bounds reject BEFORE grant", async () => {
  let grants = 0, calls = 0;
  const c = credential();
  c.dispatchGuard = dispatchGuard(
    async () => {
      grants++;
      return { data: true, error: null };
    },
    { p_kind: "vocabulary" },
    true,
  );
  for (
    const body of [{ messages: [], max_tokens: 2500 }, {
      messages: ["é".repeat(5000)],
      max_tokens: 1600,
    }, { messages: [], max_tokens: 1600, tools: [{}] }]
  ) {
    try {
      await fetchChatCompletion(c, body, {
        fetchImpl: async () => {
          calls++;
          return new Response();
        },
      });
      throw Error("unexpected");
    } catch (e) {
      assert((e as Error).message === "qa_request_bound_denied");
    }
  }
  assert(grants === 0 && calls === 0);
});
Deno.test("QA denial or unavailable policy never reaches network", async () => {
  for (
    const reply of [{ data: false, error: null }, {
      data: true,
      error: Error("offline"),
    }]
  ) {
    const c = credential();
    c.dispatchGuard = dispatchGuard(
      async () => reply,
      { p_kind: "direct" },
      false,
    );
    let calls = 0;
    try {
      await fetchChatCompletion(c, {}, {
        fetchImpl: async () => {
          calls++;
          return new Response();
        },
      });
    } catch { /* expected */ }
    assert(calls === 0);
  }
});

Deno.test("QA short vocabulary retains atomic dispatch and smaller output cap", async () => {
  let grants = 0, calls = 0;
  const c = credential();
  c.dispatchGuard = dispatchGuard(
    async () => {
      grants++;
      return { data: true, error: null };
    },
    { p_kind: "vocabulary" },
    true,
  );
  await fetchChatCompletion(c, { messages: [], max_completion_tokens: 256 }, {
    fetchImpl: async () => {
      calls++;
      return new Response("{}", {
        headers: { "content-type": "application/json" },
      });
    },
    onMetric: () => {},
  });
  assert(grants === 1 && calls === 1);
});

Deno.test("QA short cap rejects other kinds and arbitrary caps before admission", async () => {
  for (
    const [kind, cap] of [["base", 256], ["correction", 256], [
      "vocabulary",
      257,
    ], ["vocabulary", 2500]] as const
  ) {
    let grants = 0, calls = 0;
    const c = credential();
    c.dispatchGuard = dispatchGuard(
      async () => {
        grants++;
        return { data: true, error: null };
      },
      { p_kind: kind },
      true,
    );
    let denied = false;
    try {
      await fetchChatCompletion(
        c,
        { messages: [], max_completion_tokens: cap },
        {
          fetchImpl: async () => {
            calls++;
            return new Response("{}");
          },
        },
      );
    } catch (e) {
      denied = (e as Error).message === "qa_request_bound_denied";
    }
    assert(denied && grants === 0 && calls === 0);
  }
});
Deno.test("QA short vocabulary cannot dispatch twice", async () => {
  let consumed = false, calls = 0;
  const c = credential();
  c.dispatchGuard = dispatchGuard(
    async () => {
      if (consumed) return { data: false, error: null };
      consumed = true;
      return { data: true, error: null };
    },
    { p_kind: "vocabulary" },
    true,
  );
  const run = () =>
    fetchChatCompletion(c, { messages: [], max_completion_tokens: 256 }, {
      fetchImpl: async () => {
        calls++;
        return new Response("{}", {
          headers: { "content-type": "application/json" },
        });
      },
      onMetric: () => {},
    });
  const results = await Promise.allSettled([run(), run()]);
  assert(
    calls === 1 && results.filter((r) => r.status === "fulfilled").length === 1,
  );
});
