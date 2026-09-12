import { OPENROUTER_PROVIDER } from "./contract.ts";
import { fetchChatCompletion, ProviderFetchError } from "./provider.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

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
