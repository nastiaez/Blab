import { OPENROUTER_PROVIDER, type ProviderCredential } from "./contract.ts";

export class ProviderFetchError extends Error {
  constructor(
    public readonly reason: "provider_timeout" | "provider_unreachable",
  ) {
    super(reason);
    this.name = "ProviderFetchError";
  }
}

export type FetchLike = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

const DEFAULT_PROVIDER_TIMEOUT_MS = 20_000;

function chatCompletionEndpoint(credential: ProviderCredential): string {
  return credential.provider === "openrouter"
    ? "https://openrouter.ai/api/v1/chat/completions"
    : "https://api.openai.com/v1/chat/completions";
}

export async function fetchChatCompletion(
  credential: ProviderCredential,
  body: Record<string, unknown>,
  options: { timeoutMs?: number; fetchImpl?: FetchLike } = {},
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(
    () => controller.abort("provider_timeout"),
    Math.max(1, options.timeoutMs ?? DEFAULT_PROVIDER_TIMEOUT_MS),
  );
  const fetchImpl = options.fetchImpl ?? fetch;
  try {
    return await fetchImpl(chatCompletionEndpoint(credential), {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${credential.apiKey}`,
      },
      signal: controller.signal,
      body: JSON.stringify({
        ...body,
        model: credential.model,
        ...(credential.provider === "openrouter" &&
            credential.useOpenRouterProviderPolicy
          ? { provider: OPENROUTER_PROVIDER }
          : {}),
      }),
    });
  } catch (error) {
    if (controller.signal.aborted) {
      throw new ProviderFetchError("provider_timeout");
    }
    if (error instanceof ProviderFetchError) throw error;
    throw new ProviderFetchError("provider_unreachable");
  } finally {
    clearTimeout(timeout);
  }
}
