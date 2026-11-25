import {
  enrichmentKey,
  HostedEnrichment,
  type Rpc,
  runtimeMode,
} from "./hosted.ts";
import {
  type Context,
  DiveError,
  type DiveRequest,
  parseRequest,
} from "./contract.ts";
function assert(x: unknown) {
  if (!x) throw Error("assert");
}
async function rejects(f: () => unknown | Promise<unknown>, code?: string) {
  try {
    await f();
  } catch (e) {
    if (code) assert(e instanceof DiveError && e.code === code);
    return;
  }
  throw Error("Expected refusal");
}
const r: DiveRequest = {
  messageId: "11111111-1111-4111-8111-111111111111",
  kind: "vocabulary",
  text: "Hola",
  start: 0,
  end: 4,
  targetLang: "es",
  knownLang: "en",
  aidsEnabled: true,
};
const c: Context = {
  viewerId: "viewer",
  senderId: "author",
  source: "Hola",
  translation: "Hola",
  targetLang: "es",
  knownLang: "en",
  revision: 1,
  sourceVersion: "a".repeat(64),
  tokens: [],
};
const lease = "11111111-1111-4111-8111-111111111111";
Deno.test("hosted activation requires the exact project and opt-in for each environment", async () => {
  assert(runtimeMode("local", "http://127.0.0.1", "false") === "local");
  assert(
    runtimeMode(
      "staging",
      "https://tpfksdljkfnenjfdbane.supabase.co",
      "true",
    ) === "hosted",
  );
  assert(
    runtimeMode(
      "production",
      "https://lwsscssuktjlmiqryfnq.supabase.co",
      "true",
    ) ===
      "production",
  );
  for (
    const [env, url, flag] of [
      ["production", "https://lwsscssuktjlmiqryfnq.supabase.co", "false"],
      ["production", "https://bhzcexhebjszwyqvcsxs.supabase.co", "true"],
      ["production", "https://tpfksdljkfnenjfdbane.supabase.co", "true"],
      ["staging", "https://lwsscssuktjlmiqryfnq.supabase.co", "true"],
      ["staging", "https://tpfksdljkfnenjfdbane.supabase.co", "false"],
      ["staging", "http://127.0.0.1", "true"],
      ["staging", "https://foreign.supabase.co", "true"],
    ]
  ) await rejects(() => runtimeMode(env, url, flag), "local_only");
});
Deno.test("key binds viewer/source/known/learning/revision/accepted text/span/kind/replacement", async () => {
  const key = await enrichmentKey(r, c);
  assert(key === await enrichmentKey({ ...r }, { ...c }));
  for (
    const patch of [
      { viewerId: "other" },
      { sourceVersion: "b".repeat(64) },
      { knownLang: "uk" },
      { targetLang: "de" },
      { revision: 2 },
      { translation: "changed" },
    ]
  ) assert(key !== await enrichmentKey(r, { ...c, ...patch }));
  for (
    const patch of [{ start: 1 }, { text: "Hola!" }, {
      kind: "correction" as const,
      replacement: "fui",
    }, { messageId: "22222222-2222-4222-8222-222222222222" }]
  ) assert(key !== await enrichmentKey({ ...r, ...patch }, c));
});
Deno.test("cached normalized result makes no lease publication or second admission", async () => {
  let calls = 0;
  const rpc: Rpc = async (name) => {
    calls++;
    assert(name === "claim_hosted_deep_dive_enrichment");
    return {
      data: {
        status: "cached",
        admissionClass: "tester",
        analysis: { meaning: "hello" },
      },
      error: null,
    };
  };
  const store = new HostedEnrichment(rpc, r, c, "k");
  assert((await store.claim())?.meaning === "hello");
  await store.complete({ meaning: "hello" });
  await store.fail();
  assert(calls === 1);
});
Deno.test("pending/rate/forbidden/failed fail closed without acquiring a lease", async () => {
  for (
    const [status, code] of [
      ["pending", "analysis_pending"],
      ["rate_limited", "analysis_rate_limited"],
      ["forbidden", "forbidden"],
      ["failed", "analysis_unavailable"],
    ]
  ) {
    let calls = 0;
    const store = new HostedEnrichment(
      async () => {
        calls++;
        return { data: { status }, error: null };
      },
      r,
      c,
      "k",
    );
    await rejects(() => store.claim(), code);
    await store.fail();
    assert(calls === 1);
  }
});
Deno.test("service arguments derive authenticated context, explicit retry only; lease fencing honored", async () => {
  const calls: { name: string; args: Record<string, unknown> }[] = [];
  const store = new HostedEnrichment(
    async (name, args) => {
      calls.push({ name, args });
      return {
        data: name === "claim_hosted_deep_dive_enrichment"
          ? { status: "claimed", lease, admissionClass: "tester" }
          : true,
        error: null,
      };
    },
    { ...r, retry: true },
    c,
    "context",
  );
  assert(await store.claim() === null);
  await store.complete({ meaning: "hello" });
  await store.fail();
  assert(calls.length === 2);
  assert(
    calls[0].args.p_viewer === c.viewerId && calls[0].args.p_retry === true &&
      calls[0].args.p_message === r.messageId,
  );
  assert(
    calls[1].args.p_lease === lease && calls[1].args.p_context === "context",
  );
  assert(!JSON.stringify(calls).includes("Bearer"));
});
Deno.test("late lease completion rejected; failure uses original owned lease and never refunds quota", async () => {
  const calls: Record<string, unknown>[] = [];
  const store = new HostedEnrichment(
    async (name, args) => {
      calls.push(args);
      return {
        data: name === "claim_hosted_deep_dive_enrichment"
          ? { status: "claimed", lease, admissionClass: "tester" }
          : false,
        error: null,
      };
    },
    r,
    c,
    "k",
  );
  await store.claim();
  await rejects(() => store.complete({ meaning: "hello" }), "stale_context");
  await store.fail();
  assert(
    calls.length === 3 && calls[2].p_analysis === null &&
      calls[2].p_lease === lease,
  );
});
Deno.test("malformed cache and unavailable RPC never produce successful metadata", async () => {
  const store = new HostedEnrichment(
    async () => ({
      data: { status: "cached", admissionClass: "tester", analysis: {} },
      error: null,
    }),
    r,
    c,
    "k",
  );
  await rejects(() => store.claim());
  const unavailable = new HostedEnrichment(
    async () => ({ data: null, error: { message: "private" } }),
    r,
    c,
    "k",
  );
  await rejects(() => unavailable.claim(), "analysis_unavailable");
});
Deno.test("retry flag rejects nonboolean request data", () => {
  for (const retry of ["true", 1, {}, null]) {
    let failed = false;
    try {
      parseRequest({ ...r, retry });
    } catch {
      failed = true;
    }
    assert(failed);
  }
  assert(parseRequest({ ...r, retry: true }).retry === true);
});

Deno.test("hosted policy refusal never falls back to canonical local admission", async () => {
  const names: string[] = [];
  const store = new HostedEnrichment(
    async (name) => {
      names.push(name);
      return { data: { status: "forbidden" }, error: null };
    },
    r,
    c,
    "context",
  );
  await rejects(() => store.claim(), "forbidden");
  await store.fail();
  assert(
    names.length === 1 && names[0] === "claim_hosted_deep_dive_enrichment",
  );
});
Deno.test("SQL admission class selects QA or ordinary lease dispatch", async () => {
  for (const admissionClass of ["qa", "tester"]) {
    const store = new HostedEnrichment(
      async () => ({
        data: {
          status: "claimed",
          lease,
          admissionClass,
          ...(admissionClass === "qa" ? { qaNonce: lease } : {}),
        },
        error: null,
      }),
      r,
      c,
      "context",
      "a".repeat(40),
    );
    await store.claim();
    const calls: { name: string; args: Record<string, unknown> }[] = [];
    const guard = store.dispatch(async (name, args) => {
      calls.push({ name, args });
      return { data: true, error: null };
    });
    assert(guard.bounded === (admissionClass === "qa"));
    await guard.authorize();
    assert(
      calls[0].name ===
        (admissionClass === "qa"
          ? "qa_provider_dispatch"
          : "staging_deep_dive_dispatch"),
    );
    assert(
      admissionClass === "qa"
        ? calls[0].args.p_nonce === lease
        : calls[0].args.p_lease === lease && !("p_nonce" in calls[0].args),
    );
  }
});
Deno.test("unknown admission class and contradictory nonce fail closed", async () => {
  for (
    const extra of [
      {},
      { admissionClass: "unknown" },
      { admissionClass: "qa" },
      { admissionClass: "tester", qaNonce: lease },
    ]
  ) {
    const store = new HostedEnrichment(
      async () => ({
        data: { status: "claimed", lease, ...extra },
        error: null,
      }),
      r,
      c,
      "k",
    );
    await rejects(() => store.claim(), "analysis_unavailable");
    await rejects(
      () => store.dispatch(async () => ({ data: true, error: null })),
      "analysis_unavailable",
    );
  }
});

Deno.test("production only claims and dispatches via production gates", async () => {
  const calls: string[] = [];
  const store = new HostedEnrichment(
    async (name) => {
      calls.push(name);
      return {
        data: calls.length === 1
          ? { status: "claimed", lease, admissionClass: "tester" }
          : true,
        error: null,
      };
    },
    r,
    c,
    "context",
    "a".repeat(40),
    true,
  );
  assert(await store.claim() === null);
  await store.dispatch(async (name) => {
    calls.push(name);
    return { data: true, error: null };
  }).authorize();
  assert(
    calls.join(",") ===
      "claim_production_deep_dive_enrichment,production_deep_dive_dispatch",
  );
});

Deno.test("short cache separates full keys and refuses full payload on short hit", async () => {
  const full = await enrichmentKey(r, c);
  assert(full === await enrichmentKey({ ...r, mode: "full" }, c));
  assert(full !== await enrichmentKey({ ...r, mode: "short" }, c));
  const short = { ...r, mode: "short" as const };
  const hit = (analysis: unknown): Rpc => async () => ({
    data: { status: "cached", admissionClass: "tester", analysis },
    error: null,
  });
  const instance = (analysis: unknown) =>
    new HostedEnrichment(hit(analysis), short, c, "short-key");
  assert((await instance({ meaning: "hello" }).claim())?.meaning === "hello");
  await rejects(
    () => instance({ meaning: "hello", explanation: "full" }).claim(),
    "invalid_analysis",
  );
});
