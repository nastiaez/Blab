import { providerCredentials } from "../translate-message/contract.ts";
export function deepDiveProvider(
  get: (name: string) => string | undefined,
  mode: "local" | "hosted" | "production",
) {
  return providerCredentials({
    provider: get("BLAB_TRANSLATION_PROVIDER"),
    openRouterKey: get("OPEN_ROUTER_KEY"),
    openAiKey: get("OPENAI_API_KEY"),
    openRouterModel: get("OPENROUTER_MODEL"),
    openAiModel: get("OPENAI_MODEL"),
    openRouterProviderPolicy: get("OPENROUTER_PROVIDER_POLICY"),
    environment: mode === "hosted" ? "staging" : mode,
  })[0];
}
