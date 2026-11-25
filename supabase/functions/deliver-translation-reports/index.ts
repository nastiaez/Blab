import { createClient } from "@supabase/supabase-js";
import { deliverReport, type Report } from "./linear.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return Response.json({ error: "method_not_allowed" }, { status: 405 });
  }
  const authority = Deno.env.get("BLAB_SUPABASE_SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (
    !authority || request.headers.get("Authorization") !== `Bearer ${authority}`
  ) {
    return Response.json({ error: "unauthorized" }, { status: 401 });
  }

  const url = Deno.env.get("SUPABASE_URL");
  const apiKey = Deno.env.get("BLAB_TRANSLATION_LINEAR_API_KEY");
  const teamId = Deno.env.get("BLAB_TRANSLATION_LINEAR_TEAM_ID");
  if (!url || !apiKey || !teamId) {
    return Response.json({ error: "delivery_not_configured" }, { status: 503 });
  }

  const admin = createClient(url, authority, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await admin.rpc("claim_translation_report_linear");
  if (error) {
    return Response.json({ error: "delivery_claim_failed" }, { status: 503 });
  }

  const results = await Promise.allSettled(
    ((data ?? []) as Report[]).map(async (report) => {
      const identifier = await deliverReport(report, apiKey, teamId);
      const { error: finishError } = await admin.rpc(
        "finish_translation_report_linear",
        { p_report_id: report.report_id, p_identifier: identifier },
      );
      if (finishError) throw new Error("delivery_finish_failed");
    }),
  );
  const pending = results.filter((result) =>
    result.status === "rejected"
  ).length;
  return Response.json(
    { delivered: results.length - pending, pending },
    { status: pending ? 503 : 200 },
  );
});
