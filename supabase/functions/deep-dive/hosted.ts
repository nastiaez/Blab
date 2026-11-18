import {
  type Analysis,
  type Context,
  DiveError,
  type DiveRequest,
  parseAnalysis,
} from "./contract.ts";
export function runtimeMode(
  environment: string | undefined,
  url: string | undefined,
  enabled: string | undefined,
): "local" | "hosted" {
  if (environment === "local") return "local";
  if (
    environment === "staging" && enabled === "true" &&
    url === "https://tpfksdljkfnenjfdbane.supabase.co"
  ) return "hosted";
  throw new DiveError("local_only", 503);
}
export async function enrichmentKey(r: DiveRequest, c: Context) {
  const bytes = new TextEncoder().encode(
    JSON.stringify([
      "deep-dive-v1",
      c.viewerId,
      r.messageId,
      c.sourceVersion,
      c.knownLang,
      c.targetLang,
      c.revision,
      c.translation,
      r.kind,
      r.text,
      r.start,
      r.end,
      r.replacement ?? null,
    ]),
  );
  return Array.from(
    new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)),
    (b) => b.toString(16).padStart(2, "0"),
  ).join("");
}
export type Rpc = (
  name: string,
  args: Record<string, unknown>,
) => Promise<{ data: unknown; error: unknown }>;
export class HostedEnrichment {
  private lease: string | null = null;
  qaNonce: string | null = null;
  constructor(
    private rpc: Rpc,
    private r: DiveRequest,
    private c: Context,
    private key: string,
  ) {}
  async claim(): Promise<Analysis | null> {
    const { data, error } = await this.rpc("claim_hosted_qa_deep_dive_enrichment", {
      p_viewer: this.c.viewerId,
      p_message: this.r.messageId,
      p_context: this.key,
      p_source: this.c.sourceVersion,
      p_known: this.c.knownLang,
      p_target: this.c.targetLang,
      p_revision: this.c.revision,
      p_kind: this.r.kind,
      p_retry: this.r.retry === true,
    });
    if (error || !data || typeof data !== "object") {
      throw new DiveError("analysis_unavailable", 503);
    }
    const value = data as Record<string, unknown>;
    if (value.status === "cached") {
      return parseAnalysis(value.analysis, this.r.kind);
    }
    if (
      value.status === "claimed" && typeof value.lease === "string" &&
      /^[0-9a-f-]{36}$/i.test(value.lease)
    ) {
      this.lease = value.lease;
      this.qaNonce = typeof value.qaNonce === "string" ? value.qaNonce : null;
      return null;
    }
    if (value.status === "rate_limited") {
      throw new DiveError("analysis_rate_limited", 429);
    }
    if (value.status === "pending") {
      throw new DiveError("analysis_pending", 409);
    }
    if (value.status === "forbidden") throw new DiveError("forbidden", 403);
    throw new DiveError("analysis_unavailable", 503);
  }
  async complete(analysis: Analysis) {
    if (!this.lease) return;
    const { data, error } = await this.rpc("finish_deep_dive_enrichment", {
      p_viewer: this.c.viewerId,
      p_context: this.key,
      p_lease: this.lease,
      p_analysis: analysis,
    });
    if (error || data !== true) throw new DiveError("stale_context", 409);
    this.lease = null;
  }
  async fail() {
    if (!this.lease) return;
    try {
      await this.rpc("finish_deep_dive_enrichment", {
        p_viewer: this.c.viewerId,
        p_context: this.key,
        p_lease: this.lease,
        p_analysis: null,
      });
    } finally {
      this.lease = null;
    }
  }
}
