import { dispatchGuard, type QaRpc } from "../_shared/qa_budget.ts";
import { enrichmentKey, HostedEnrichment, runtimeMode } from "./hosted.ts";
import { acceptedContext, historicalEra } from "./accepted_context.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { BodyTooLarge, readBoundedBody } from "../_shared/bounded_body.ts";
import { deepDiveProvider } from "./provider_config.ts";
import { fetchChatCompletion } from "../translate-message/provider.ts";
import {
  analysisMessages,
  type Context,
  DiveError,
  parseAnalysis,
  parseRequest,
  validateContext,
} from "./contract.ts";
const headers = {
  "Cache-Control": "no-store",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (value: unknown, status = 200) =>
  Response.json(value, { status, headers });
export async function handle(request: Request): Promise<Response> {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers });
  }
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  let mode: "local" | "hosted";
  try {
    mode = runtimeMode(
      Deno.env.get("DEEP_DIVE_ENVIRONMENT") || Deno.env.get("BLAB_ENV"),
      Deno.env.get("SUPABASE_URL"),
      Deno.env.get("DEEP_DIVE_HOSTED_ENABLED"),
    );
  } catch {
    return json({ error: "local_only" }, 503);
  }
  let hosted: HostedEnrichment | undefined;
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json({ error: "authentication_required" }, 401);
  }
  try {
    const r = parseRequest(
      JSON.parse(
        new TextDecoder().decode(await readBoundedBody(request, 32768)),
      ),
    );
    const url = Deno.env.get("SUPABASE_URL")!;
    if (
      mode === "local" &&
      !["localhost", "127.0.0.1", "kong", "host.docker.internal"].includes(
        new URL(url).hostname,
      )
    ) throw new DiveError("local_database_required", 503);
    const client = createClient(
      url,
      Deno.env.get("BLAB_SUPABASE_ANON_KEY") ||
        Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: { headers: { Authorization: authorization } },
        auth: { persistSession: false, autoRefreshToken: false },
      },
    );
    const { data: identity, error: authError } = await client.auth.getUser();
    if (authError || !identity.user) {
      throw new DiveError("authentication_required", 401);
    }
    const viewer = identity.user.id;
    // Caller JWT/RLS, never service-role bypass. No translation admission RPC: it can enqueue work.
    const [{ data: m, error: me }, { data: p, error: pe }] = await Promise.all([
      client.from("messages").select(
        "chat_id,sender_id,body,created_at,deleted_at,languages_matched_at_send",
      ).eq(
        "id",
        r.messageId,
      ).maybeSingle(),
      client.from("profiles").select(
        "primary_known_language,account_deleted_at",
      ).eq("id", viewer).maybeSingle(),
    ]);
    if (me || pe || !m || m.deleted_at || !p || p.account_deleted_at) {
      throw new DiveError("forbidden", 403);
    }
    const { data: membership, error: ce } = await client.from("chat_members")
      .select("user_id,mode,learning_language,learning_language_revision").eq(
        "chat_id",
        m.chat_id,
      ).eq("user_id", viewer)
      .maybeSingle();
    if (ce || !membership) throw new DiveError("forbidden", 403);
    if (membership.mode === "none") {
      throw new DiveError("learning_aids_off", 403);
    }
    const hash = Array.from(
      new Uint8Array(
        await crypto.subtle.digest(
          "SHA-256",
          new TextEncoder().encode(m.body.trim()),
        ),
      ),
      (b) => b.toString(16).padStart(2, "0"),
    ).join("");
    const { data: timeline, error: timelineError } = await client.from(
      "chat_language_timeline",
    )
      .select("revision,learning_language,created_at").eq("chat_id", m.chat_id)
      .eq("user_id", viewer).order("revision");
    if (timelineError) throw new DiveError("accepted_context_unavailable");
    const era = historicalEra(
      timeline ?? [],
      m.created_at,
      membership.learning_language,
      membership.learning_language_revision,
    );
    if (
      era.language !== r.targetLang ||
      (r.languageRevision !== undefined && r.languageRevision !== era.revision)
    ) throw new DiveError("preferences_changed");
    const contextIdentity = {
      viewerId: viewer,
      senderId: m.sender_id,
      languagesMatchedAtSend: m.languages_matched_at_send === true,
      source: m.body,
      targetLang: era.language,
      knownLang: p.primary_known_language,
      revision: era.revision,
      sourceVersion: hash,
    };
    const { data: packages, error: ke } = await client.from(
      "message_prepared_packages",
    ).select("*")
      .eq("message_id", r.messageId).eq("viewer_id", viewer).eq(
        "status",
        "ready",
      ).eq("source_version", hash)
      .eq("learning_language", era.language).eq(
        "language_revision",
        era.revision,
      ).eq("primary_known_language", p.primary_known_language).limit(1);
    if (ke) throw new DiveError("accepted_context_unavailable");
    let c: Context | undefined;
    if (packages?.[0]) {
      try {
        c = acceptedContext(r, contextIdentity, packages[0], "prepared");
      } catch (error) {
        if (
          !(error instanceof DiveError) ||
          error.code !== "accepted_context_unavailable"
        ) throw error;
      }
    }
    if (!c) {
      // Read-only legacy fallback uses the exact current source hash and caller RLS.
      const { data: legacy, error: legacyError } = await client.from(
        "message_translations",
      ).select("*")
        .eq("message_id", r.messageId).eq("target_lang", era.language).eq(
          "interface_lang",
          p.primary_known_language,
        ).eq("source_hash", hash).maybeSingle();
      if (legacyError || !legacy) {
        throw new DiveError("accepted_context_unavailable");
      }
      c = acceptedContext(r, contextIdentity, legacy, "legacy");
    }
    validateContext(r, c);
    // No new paid calls are authorized for this task. Remains off unless separately authorized.
    if (Deno.env.get("DEEP_DIVE_ALLOW_PROVIDER") !== "true") {
      throw new DiveError("analysis_provider_disabled", 503);
    }
    const messages = analysisMessages(r, c);
    if (new TextEncoder().encode(JSON.stringify(messages)).length > 10000) {
      throw new DiveError("invalid_request", 400);
    }
    let providerRpc: QaRpc | undefined;
    let analysis;
    if (mode === "hosted") {
      const service = Deno.env.get("BLAB_SUPABASE_SERVICE_ROLE_KEY") ||
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
      if (!service) throw new DiveError("analysis_provider_unavailable", 503);
      const admin = createClient(url, service, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
      providerRpc = async (name, args) => await admin.rpc(name, args);
      hosted = new HostedEnrichment(
        async (name, args) => await admin.rpc(name, args),
        r,
        c,
        await enrichmentKey(r, c),
        Deno.env.get("BLAB_DEEP_DIVE_RELEASE_REVISION") ?? "",
      );
      analysis = await hosted.claim();
    }
    if (!analysis) {
      const credential = deepDiveProvider((name) => Deno.env.get(name), mode);
      if (!credential) {
        throw new DiveError("analysis_provider_unavailable", 503);
      }
      if (providerRpc) {
        credential.dispatchGuard = hosted
          ? hosted.dispatch(providerRpc)
          : dispatchGuard(providerRpc, {
            p_message: r.messageId,
            p_source: hash,
            p_kind: r.kind,
            p_nonce: null,
          }, true);
      }
      const response = await fetchChatCompletion(credential, {
        messages,
        response_format: { type: "json_object" },
        max_completion_tokens: 1600,
      });
      if (!response.ok) throw new DiveError("analysis_unavailable", 502);
      const payload = await response.json();
      analysis = parseAnalysis(
        JSON.parse(payload.choices?.[0]?.message?.content),
        r.kind,
      );
    }
    // Generation/cache access can outlive an edit, account deletion or membership change.
    const [latestMessage, latestProfile, latestMembership] = await Promise.all([
      client.from("messages").select(
        "body,deleted_at,languages_matched_at_send",
      ).eq("id", r.messageId).maybeSingle(),
      client.from("profiles").select(
        "primary_known_language,account_deleted_at",
      ).eq("id", viewer).maybeSingle(),
      client.from("chat_members").select(
        "user_id,mode,learning_language,learning_language_revision",
      ).eq(
        "chat_id",
        m.chat_id,
      ).eq("user_id", viewer).maybeSingle(),
    ]);
    if (
      latestMessage.error || latestProfile.error || latestMembership.error ||
      !latestMessage.data || latestMessage.data.deleted_at ||
      latestMessage.data.body !== c.source ||
      !latestProfile.data || latestProfile.data.account_deleted_at ||
      latestProfile.data.primary_known_language !== c.knownLang ||
      !latestMembership.data || latestMembership.data.mode === "none" ||
      (r.kind === "correction" && c.senderId !== viewer &&
        latestMessage.data.languages_matched_at_send !== true)
    ) {
      throw new DiveError("stale_context", 409);
    }
    await hosted?.complete(analysis);
    return json({
      ...analysis,
      kind: r.kind,
      explanationLanguage: c.knownLang,
      audio: {
        text: r.kind === "correction"
          ? r.replacement
          : r.text.slice(r.start, r.end),
        language: c.targetLang,
      },
      provenance: {
        messageId: r.messageId,
        sourceVersion: hash,
        acceptedText: c.translation,
        sourceText: c.source,
        languageRevision: c.revision,
        start: r.start,
        end: r.end,
      },
    });
  } catch (e) {
    try {
      await hosted?.fail();
    } catch { /* lease expires; no quota refund or retry */ }
    if (e instanceof BodyTooLarge) {
      return json({ error: "body_too_large" }, 413);
    }
    if (e instanceof DiveError) return json({ error: e.code }, e.status);
    if (e instanceof SyntaxError) return json({ error: "invalid_json" }, 400);
    return json({ error: "analysis_unavailable" }, 502);
  }
}
if (import.meta.main) Deno.serve(handle);
