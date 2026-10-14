import {
  fetchChatCompletion,
  measuredUsage,
  type ProviderMetric,
} from "./provider.ts";

Deno.test("cache telemetry distinguishes measured zero from absent or invalid usage", () => {
  for (
    const [payload, expected] of [
      [{
        usage: {
          prompt_tokens: 1500,
          completion_tokens: 30,
          prompt_tokens_details: { cached_tokens: 1024 },
        },
      }, 1024],
      [{
        usage: {
          prompt_tokens: 1500,
          prompt_tokens_details: { cached_tokens: 0 },
        },
      }, 0],
      [{ usage: { prompt_tokens: 1500 } }, null],
      [{
        usage: {
          prompt_tokens: 10,
          prompt_tokens_details: { cached_tokens: 100 },
        },
      }, null],
      [null, null],
    ] as const
  ) {
    if (measuredUsage(payload).cachedPromptTokens !== expected) {
      throw new Error("cache usage was guessed");
    }
  }
});
Deno.test("metrics do not consume the caller response or expose request contents", async () => {
  let metric: ProviderMetric | null = null;
  const payload = {
    choices: [{ message: { content: "private-result" } }],
    usage: {
      prompt_tokens: 2000,
      completion_tokens: 40,
      prompt_tokens_details: { cached_tokens: 1024 },
    },
  };
  const response = await fetchChatCompletion(
    {
      provider: "openrouter",
      model: "fixture",
      apiKey: "private-key",
      useOpenRouterProviderPolicy: true,
    },
    { messages: [{ role: "user", content: "private-prompt" }] },
    {
      fetchImpl: () => Promise.resolve(Response.json(payload)),
      onMetric: (value) => {
        metric = value;
      },
    },
  );
  if (JSON.stringify(await response.json()) !== JSON.stringify(payload)) {
    throw new Error("response consumed");
  }
  const serialized = JSON.stringify(metric);
  if (/private-/.test(serialized)) {
    throw new Error("private input leaked into telemetry");
  }
  if (metric === null || measuredUsage(payload).cachedPromptTokens !== 1024) {
    throw new Error("actual usage missing");
  }
});
Deno.test("a failed telemetry callback cannot fail delivery", async () => {
  const result = await fetchChatCompletion(
    {
      provider: "openrouter",
      model: "fixture",
      apiKey: "fixture",
      useOpenRouterProviderPolicy: true,
    },
    {},
    {
      fetchImpl: () => Promise.resolve(Response.json({ choices: [] })),
      onMetric: () => {
        throw new Error("monitor unavailable");
      },
    },
  );
  if (result.status !== 200) throw new Error("monitor prevented delivery");
});
