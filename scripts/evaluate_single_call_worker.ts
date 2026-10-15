// Local isolated database test, never a production connection.
import {
  type LeasedJob,
  runMessageBatch,
} from "../supabase/functions/prepare-message-jobs/single_call_worker.ts";
const quote = (v: unknown) =>
  typeof v === "number"
    ? String(v)
    : v === null
    ? "null"
    : `'${
      (typeof v === "object" ? JSON.stringify(v) : String(v)).replaceAll(
        "'",
        "''",
      )
    }'`;
async function sql(query: string) {
  const r = await new Deno.Command("docker", {
    args: [
      "exec",
      "supabase_db_Blab_Stream_Clean_20261014",
      "psql",
      "-U",
      "postgres",
      "-d",
      "postgres",
      "-qAt",
      "-v",
      "ON_ERROR_STOP=1",
      "-c",
      `set request.jwt.claims='{"role":"service_role"}'; ${query}`,
    ],
    stdout: "piped",
    stderr: "piped",
  }).output();
  if (!r.success) throw new Error(new TextDecoder().decode(r.stderr));
  const text = new TextDecoder().decode(r.stdout).trim();
  return text ? JSON.parse(text) : null;
}
const admin = {
  async rpc(name: string, args: Record<string, unknown>) {
    try {
      return {
        data: await sql(
          `select to_jsonb(${name}(${
            Object.entries(args).map(([k, v]) => `${k}=>${quote(v)}`).join(",")
          }));`,
        ),
        error: null,
      };
    } catch (e) {
      console.log("rpc_failure", name, String(e));
      return { data: null, error: String(e) };
    }
  },
};
const jobs = await sql(
  "select coalesce(jsonb_agg(j),'[]') from claim_message_preparation_jobs_for_worker(1) j",
) as LeasedJob[];
if (jobs.length !== 2) throw new Error("expected_two_claimed_jobs");
await runMessageBatch(admin, jobs);
const result = await sql(
  "select jsonb_agg(jsonb_build_object('status',j.status,'attempts',j.attempts,'target',j.learning_language,'error',j.last_error,'translation',r.result->>'translation','secondary',r.result->>'interfaceText')) from message_preparation_jobs j left join message_readable_variants r on r.message_id=j.message_id and r.viewer_id=j.viewer_id",
);
console.log(JSON.stringify(result));
if (
  !result.every((r: { status: string; attempts: number }) =>
    r.status === "ready" && r.attempts === 1
  )
) throw new Error("worker_not_ready");
