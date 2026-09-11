function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

const migrationUrl = new URL(
  "../../migrations/20260911000001_harden_automatic_form_cache.sql",
  import.meta.url,
);
const edgeFunctionUrl = new URL("./index.ts", import.meta.url);

Deno.test("automatic-form migration invalidates every legacy cache variant", async () => {
  const sql = (await Deno.readTextFile(migrationUrl))
    .replace(/--.*$/gm, "")
    .replace(/\s+/g, " ")
    .replace(/\(\s+/g, "(")
    .replace(/\s+\)/g, ")")
    .trim()
    .toLowerCase();

  assert(
    sql.includes("delete from public.message_prepared_packages;"),
    "all prepared packages must be invalidated, including rows with null form_alternatives",
  );
  assert(
    sql.includes("delete from public.message_translations;"),
    "all shared translations must be invalidated, including rows with null form_alternatives",
  );
});

Deno.test("automatic-form migration replaces invalidated preparation jobs", async () => {
  const sql = (await Deno.readTextFile(migrationUrl))
    .replace(/--.*$/gm, "")
    .replace(/\s+/g, " ")
    .replace(/\(\s+/g, "(")
    .replace(/\s+\)/g, ")")
    .trim()
    .toLowerCase();

  assert(
    sql.includes("delete from public.message_preparation_jobs"),
    "legacy job IDs must be deleted so old workers cannot complete them",
  );
  assert(
    sql.includes("returning message_id, chat_id, viewer_id"),
    "the replacement must preserve the job variant without preserving its ID",
  );
  assert(
    sql.includes("where status in ('processing', 'ready')"),
    "ready and in-flight legacy jobs must both be replaced",
  );
  assert(
    sql.includes("insert into public.message_preparation_jobs"),
    "invalidated job variants must be recreated with fresh IDs",
  );
  assert(
    sql.indexOf("delete from public.message_preparation_jobs") <
      sql.indexOf("delete from public.message_prepared_packages"),
    "old workers must settle before their legacy package output is purged",
  );
  assert(
    sql.indexOf("delete from public.message_preparation_jobs") <
      sql.indexOf("delete from public.message_translations"),
    "old workers must settle before their legacy translation output is purged",
  );
});

Deno.test("automatic-form migration rejects every legacy completion contract", async () => {
  const sql = (await Deno.readTextFile(migrationUrl))
    .replace(/--.*$/gm, "")
    .replace(/\s+/g, " ")
    .replace(/\(\s+/g, "(")
    .replace(/\s+\)/g, ")")
    .trim()
    .toLowerCase();

  assert(
    sql.match(/p_cache_contract_version text/g)?.length === 2,
    "foreground and worker completions must both require a cache contract version",
  );
  assert(
    sql.match(/p_cache_contract_version <> 'automatic-forms-v2'/g)?.length ===
      2,
    "both completion paths must reject pre-v2 callers",
  );
  assert(
    sql.includes(
      "revoke all on function public.complete_message_translation(uuid, uuid, text, text, text, text, text, text, text, text, text, jsonb, jsonb) from public, anon, authenticated, service_role",
    ),
    "the legacy foreground completion overload must no longer be callable",
  );
  assert(
    sql.includes(
      "revoke all on function public.complete_message_translation_job(uuid, text, text, text, text, text, text, jsonb, jsonb) from public, anon, authenticated, service_role",
    ),
    "the legacy worker completion overload must no longer be callable",
  );

  const edgeFunction = await Deno.readTextFile(edgeFunctionUrl);
  assert(
    edgeFunction.includes(
      'const CACHE_CONTRACT_VERSION = "automatic-forms-v2";',
    ),
    "the edge function must declare the database completion contract",
  );
  assert(
    edgeFunction.match(
      /p_cache_contract_version: CACHE_CONTRACT_VERSION/g,
    )?.length === 2,
    "foreground and worker RPC calls must both send the current contract",
  );
});
