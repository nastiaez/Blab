import { OPENROUTER_PROVIDER } from "./contract.ts";
import {
  completionBudget,
  fetchChatCompletion,
  ProviderFetchError,
} from "./provider.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

Deno.test("focused audits use their matching strict response schemas", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );
  const correctionBlock = source.slice(
    source.indexOf("async function auditSameLanguageCorrection"),
    source.indexOf("async function auditHindiFutureTranslation"),
  );
  const futureBlock = source.slice(
    source.indexOf("async function auditHindiFutureTranslation"),
    source.indexOf("async function auditGrammaticalForm"),
  );
  assert(
    correctionBlock.includes("CORRECTION_AUDIT_RESPONSE_FORMAT"),
    "same-language review must use the correction schema",
  );
  assert(
    correctionBlock.includes("parseCorrectionAuditCandidate"),
    "same-language review must preserve valid correction semantics",
  );
  assert(
    correctionBlock.includes("candidate.tokens !== null") &&
      correctionBlock.includes("repairWordMetadata("),
    "same-language review must repair only stale correction metadata",
  );
  assert(
    futureBlock.includes("TRANSLATION_RESPONSE_FORMAT"),
    "Hindi future rewrite must use the full translation schema",
  );
  assert(
    !futureBlock.includes("revised.translation !== candidateTranslation"),
    "the temporal audit must accept unchanged past or already-correct Hindi",
  );
});

Deno.test("provider fetch aborts and reports a controlled timeout", async () => {
  const started = Date.now();
  try {
    await fetchChatCompletion(
      {
        provider: "openrouter",
        apiKey: "router-key",
        model: "openai/gpt-4o-mini",
        useOpenRouterProviderPolicy: true,
      },
      { messages: [] },
      {
        timeoutMs: 1,
        fetchImpl: (_url, init) =>
          new Promise<Response>((_resolve, reject) => {
            init?.signal?.addEventListener("abort", () => {
              reject(new DOMException("aborted", "AbortError"));
            });
          }),
      },
    );
    throw new Error("fetch should time out");
  } catch (error) {
    if (!(error instanceof ProviderFetchError)) {
      throw new Error("timeout error type");
    }
    assert(error.reason === "provider_timeout", "timeout reason");
    assert(Date.now() - started < 1000, "timeout should be bounded");
  }
});

Deno.test("provider fetch preserves endpoint, signal, model, and privacy policy", async () => {
  const captured: Array<{ url: string; init?: RequestInit }> = [];
  const fetchImpl = (
    url: string | URL | Request,
    init?: RequestInit,
  ): Promise<Response> => {
    captured.push({ url: String(url), init });
    return Promise.resolve(new Response("{}", { status: 200 }));
  };

  await fetchChatCompletion(
    {
      provider: "openrouter",
      apiKey: "router-key",
      model: "openai/gpt-4o-mini",
      useOpenRouterProviderPolicy: true,
    },
    { temperature: 0 },
    { timeoutMs: 1000, fetchImpl },
  );
  await fetchChatCompletion(
    {
      provider: "openai",
      apiKey: "openai-key",
      model: "gpt-4o-mini",
      useOpenRouterProviderPolicy: false,
    },
    { temperature: 0 },
    { timeoutMs: 1000, fetchImpl },
  );

  assert(
    captured[0].url === "https://openrouter.ai/api/v1/chat/completions",
    "OpenRouter endpoint",
  );
  assert(
    captured[1].url === "https://api.openai.com/v1/chat/completions",
    "OpenAI endpoint",
  );
  assert(
    captured.every((request) => request.init?.signal instanceof AbortSignal),
    "every provider request receives an abort signal",
  );
  const routerBody = JSON.parse(String(captured[0].init?.body));
  const openAiBody = JSON.parse(String(captured[1].init?.body));
  assert(routerBody.model === "openai/gpt-4o-mini", "router model included");
  assert(
    JSON.stringify(routerBody.provider) === JSON.stringify(OPENROUTER_PROVIDER),
    "OpenRouter privacy policy included",
  );
  assert(openAiBody.model === "gpt-4o-mini", "OpenAI model included");
  assert(!("provider" in openAiBody), "OpenAI request omits router policy");
});

Deno.test("short messages do not reserve a long-message completion budget", () => {
  assert(
    completionBudget("Bring the book tomorrow.", "readable") === 1536,
    "short readable budget",
  );
  assert(
    completionBudget("Bring the book tomorrow.", "audit") === 768,
    "short audit budget",
  );
  assert(
    completionBudget("Bring the book tomorrow.", "metadata") === 1536,
    "short metadata budget",
  );
  assert(
    completionBudget("書".repeat(2000), "readable") === 12000,
    "long non-Latin result retains room",
  );
  assert(
    completionBudget("word ".repeat(400), "metadata") === 12000,
    "long metadata retains room",
  );
});

Deno.test("provider backoff prevents same-account hedge and retains Retry-After", async () => {
  const { fetchChatCompletion, ProviderFetchError } = await import(
    "./provider.ts"
  );
  const credential = {
    provider: "openrouter" as const,
    apiKey: "synthetic",
    model: "test",
    useOpenRouterProviderPolicy: false,
    backoff: { untilMs: 0 },
  };
  let calls = 0;
  const fetchImpl = async () => {
    calls++;
    return new Response("{}", {
      status: 429,
      headers: { "Retry-After": "120" },
    });
  };
  await fetchChatCompletion(credential, {}, { fetchImpl, onMetric: () => {} });
  let blocked = false;
  try {
    await fetchChatCompletion({ ...credential, model: "fallback" }, {}, {
      fetchImpl,
    });
  } catch (e) {
    blocked = e instanceof ProviderFetchError &&
      e.reason === "provider_backoff";
  }
  assert(
    blocked && calls === 1 && credential.backoff.untilMs > Date.now() + 119000,
    "backoff is shared by model routes on the same account",
  );
});
