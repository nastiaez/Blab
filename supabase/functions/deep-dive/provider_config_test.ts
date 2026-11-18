import { deepDiveProvider } from "./provider_config.ts";
Deno.test("Deep obeys canonical BLAB provider with both credentials present", () => {
  const env: Record<string, string> = {
    BLAB_TRANSLATION_PROVIDER: "openai",
    OPEN_ROUTER_KEY: "fake-router-not-a-key",
    OPENAI_API_KEY: "fake-openai-not-a-key",
    OPENAI_MODEL: "gpt-6-luna",
  };
  const selected = deepDiveProvider((n) => env[n], "hosted");
  if (selected?.provider !== "openai" || selected.model !== "gpt-6-luna") {
    throw Error("wrong configured provider");
  }
});
Deno.test("invalid canonical provider fails closed instead of falling back", () => {
  const env: Record<string, string> = {
    BLAB_TRANSLATION_PROVIDER: "invalid",
    OPEN_ROUTER_KEY: "fake",
    OPENAI_API_KEY: "fake",
  };
  if (deepDiveProvider((n) => env[n], "hosted") !== undefined) {
    throw Error("fallback bypass");
  }
});
