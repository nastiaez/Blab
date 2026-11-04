import { providerCredentials } from "./contract.ts";
import { fetchChatCompletion } from "./provider.ts";
function assert(v: boolean, message: string) {
  if (!v) throw new Error(message);
}
Deno.test("explicit OpenAI selection never falls back to retained OpenRouter", () => {
  const env = {
    provider: "openai",
    openRouterKey: "retained",
    openAiKey: "app-key",
  };
  const credentials = providerCredentials(env);
  assert(
    credentials.length === 1 && credentials[0].provider === "openai" &&
      credentials[0].model === "gpt-6-luna",
    "exact direct model",
  );
  assert(
    providerCredentials({ ...env, openAiKey: "" }).length === 0,
    "fail closed without direct key",
  );
  assert(
    providerCredentials({ ...env, provider: "invalid" }).length === 0,
    "invalid mode fails closed",
  );
});
Deno.test("direct Luna normalizes both legacy and compact request paths without changing schemas", async () => {
  for (const budget of [{ max_tokens: 128 }, { max_completion_tokens: 128 }]) {
    await fetchChatCompletion({
      provider: "openai",
      apiKey: "synthetic",
      model: "gpt-6-luna",
      useOpenRouterProviderPolicy: false,
    }, {
      messages: [],
      temperature: 0,
      ...budget,
      response_format: { type: "json_schema" },
    }, {
      onMetric: () => {},
      fetchImpl: (url, init) => {
        const body = JSON.parse(String(init?.body));
        assert(
          String(url) === "https://api.openai.com/v1/chat/completions",
          "direct endpoint",
        );
        assert(
          body.model === "gpt-6-luna" && body.max_completion_tokens === 128,
          "exact model and token bound",
        );
        assert(
          !("temperature" in body) && !("max_tokens" in body) &&
            !("provider" in body),
          "no unsupported or router settings",
        );
        assert(body.response_format.type === "json_schema", "schema preserved");
        return Promise.resolve(new Response("{}"));
      },
    });
  }
});
