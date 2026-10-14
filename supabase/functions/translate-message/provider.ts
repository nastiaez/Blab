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

export type ProviderMetric = {
  provider: string;
  model: string;
  status: number;
  durationMs: number;
  promptTokens: number | null;
  completionTokens: number | null;
  cachedPromptTokens: number | null;
};

export function measuredUsage(payload: unknown): Pick<
  ProviderMetric,
  "promptTokens" | "completionTokens" | "cachedPromptTokens"
> {
  const value = payload as {
    usage?: {
      prompt_tokens?: unknown;
      completion_tokens?: unknown;
      prompt_tokens_details?: { cached_tokens?: unknown };
    };
  } | null;
  const integer = (v: unknown) =>
    typeof v === "number" && Number.isSafeInteger(v) && v >= 0 ? v : null;
  const promptTokens = integer(value?.usage?.prompt_tokens);
  const cached = integer(value?.usage?.prompt_tokens_details?.cached_tokens);
  return {
    promptTokens,
    completionTokens: integer(value?.usage?.completion_tokens),
    cachedPromptTokens:
      cached !== null && promptTokens !== null && cached <= promptTokens
        ? cached
        : null,
  };
}

function chatCompletionEndpoint(credential: ProviderCredential): string {
  return credential.provider === "openrouter"
    ? "https://openrouter.ai/api/v1/chat/completions"
    : "https://api.openai.com/v1/chat/completions";
}

export async function fetchChatCompletion(
  credential: ProviderCredential,
  body: Record<string, unknown>,
  options: {
    timeoutMs?: number;
    fetchImpl?: FetchLike;
    onMetric?: (metric: ProviderMetric) => void;
  } = {},
): Promise<Response> {
  const started = performance.now();
  const controller = new AbortController();
  const timeout = setTimeout(
    () => controller.abort("provider_timeout"),
    Math.max(1, options.timeoutMs ?? DEFAULT_PROVIDER_TIMEOUT_MS),
  );
  const fetchImpl = options.fetchImpl ?? fetch;
  try {
    const response = await fetchImpl(chatCompletionEndpoint(credential), {
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
    let payload: unknown = null;
    if (response.headers.get("Content-Type")?.includes("application/json")) {
      try {
        payload = await response.clone().json();
      } catch {
        if (controller.signal.aborted) {
          throw new ProviderFetchError("provider_timeout");
        }
      }
    }
    const metric: ProviderMetric = {
      provider: credential.provider,
      model: credential.model,
      status: response.status,
      durationMs: Math.round(performance.now() - started),
      ...measuredUsage(payload),
    };
    // Usage-only telemetry; never log prompts, messages or credentials.
    try {
      if (options.onMetric) options.onMetric(metric);
      else console.log("blab_provider_metric", metric);
    } catch {
      // Observability must not change an otherwise valid translation.
    }
    return response;
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

export function completionBudget(
  text: string,
  kind: "readable" | "audit" | "metadata",
): number {
  const length = [...text].length;
  if (kind === "audit") return Math.min(4000, Math.max(768, 256 + length * 4));
  if (kind === "metadata") {
    return Math.min(12000, Math.max(1536, 512 + length * 24));
  }
  return Math.min(12000, Math.max(1536, 768 + length * 8));
}
