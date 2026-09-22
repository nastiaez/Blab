function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

const migrationUrl = new URL(
  "../../migrations/20260911000001_harden_automatic_form_cache.sql",
  import.meta.url,
);
const edgeFunctionUrl = new URL("./index.ts", import.meta.url);
const languageAidsMigrationUrl = new URL(
  "../../migrations/20260921000001_complete_language_aids_cache.sql",
  import.meta.url,
);
const primaryKnownWordMetadataMigrationUrl = new URL(
  "../../migrations/20260921000002_primary_known_word_metadata_cache.sql",
  import.meta.url,
);
const semanticTranslationFidelityMigrationUrl = new URL(
  "../../migrations/20260921000003_semantic_translation_fidelity_cache.sql",
  import.meta.url,
);
const semanticConsensusMigrationUrl = new URL(
  "../../migrations/20260921000004_semantic_consensus_cache.sql",
  import.meta.url,
);
const semanticAuditPivotMigrationUrl = new URL(
  "../../migrations/20260921000005_semantic_audit_pivot_cache.sql",
  import.meta.url,
);
const sourceMeaningAnchorMigrationUrl = new URL(
  "../../migrations/20260921000006_source_meaning_anchor_cache.sql",
  import.meta.url,
);
const interfaceMeaningAuditMigrationUrl = new URL(
  "../../migrations/20260921000007_interface_meaning_audit_cache.sql",
  import.meta.url,
);
const independentSemanticReviewMigrationUrl = new URL(
  "../../migrations/20260921000008_independent_semantic_review_cache.sql",
  import.meta.url,
);
const minimalSourceAnchorMigrationUrl = new URL(
  "../../migrations/20260921000009_minimal_source_anchor_cache.sql",
  import.meta.url,
);

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
      'const CACHE_CONTRACT_VERSION = "minimal-source-anchor-v11";',
    ),
    "the edge function must declare the latest database completion contract",
  );
  assert(
    edgeFunction.match(
      /p_cache_contract_version: CACHE_CONTRACT_VERSION/g,
    )?.length === 2,
    "foreground and worker RPC calls must both send the current contract",
  );
});

Deno.test("complete-language-aids migration advances and invalidates the cache", async () => {
  const sql = (await Deno.readTextFile(languageAidsMigrationUrl))
    .replace(/--.*$/gm, "")
    .replace(/\s+/g, " ")
    .replace(/\(\s+/g, "(")
    .replace(/\s+\)/g, ")")
    .trim()
    .toLowerCase();

  assert(
    sql.match(/p_cache_contract_version <> 'complete-language-aids-v3'/g)
      ?.length === 2,
    "both completion paths must require the new language-aids contract",
  );
  assert(
    sql.includes("delete from public.message_prepared_packages;"),
    "prepared packages from the previous prompt must be invalidated",
  );
  assert(
    sql.includes("delete from public.message_translations;"),
    "shared translations from the previous prompt must be invalidated",
  );
  assert(
    sql.includes("delete from public.message_preparation_jobs"),
    "ready and in-flight jobs must be replaced before cache deletion",
  );
  assert(
    sql.includes(
      "check (cache_contract_version = 'complete-language-aids-v3')",
    ),
    "stored translations must identify the new contract",
  );
});

Deno.test("primary-known word metadata migration refreshes every stale package", async () => {
  const sql = (await Deno.readTextFile(primaryKnownWordMetadataMigrationUrl))
    .replace(/--.*$/gm, "")
    .replace(/\s+/g, " ")
    .replace(/\(\s+/g, "(")
    .replace(/\s+\)/g, ")")
    .trim()
    .toLowerCase();
  assert(
    sql.match(/p_cache_contract_version <> 'primary-known-word-metadata-v4'/g)
      ?.length === 2,
    "both completion paths must reject pre-v4 word metadata",
  );
  assert(
    sql.includes("delete from public.message_preparation_jobs"),
    "ready and in-flight jobs must be replaced before cache deletion",
  );
  assert(
    sql.includes("where status in ('processing', 'ready')"),
    "both completed and in-flight variants must regenerate",
  );
  assert(
    sql.includes("delete from public.message_prepared_packages;"),
    "prepared packages with copied meanings must be removed",
  );
  assert(
    sql.includes("delete from public.message_translations;"),
    "shared token metadata with copied meanings must be removed",
  );
  assert(
    sql.includes(
      "check (cache_contract_version = 'primary-known-word-metadata-v4')",
    ),
    "stored translations must identify the v4 contract",
  );
});

Deno.test("semantic-fidelity migration refreshes every stale translation", async () => {
  const sql = (await Deno.readTextFile(semanticTranslationFidelityMigrationUrl))
    .replace(/--.*$/gm, "")
    .replace(/\s+/g, " ")
    .replace(/\(\s+/g, "(")
    .replace(/\s+\)/g, ")")
    .trim()
    .toLowerCase();

  assert(
    sql.match(/p_cache_contract_version <> 'semantic-fidelity-v5'/g)
      ?.length === 2,
    "both completion paths must reject pre-v5 translations",
  );
  assert(
    sql.includes("delete from public.message_preparation_jobs") &&
      sql.includes("where status in ('processing', 'ready')"),
    "ready and in-flight variants must regenerate under the stronger prompt",
  );
  assert(
    sql.includes("delete from public.message_prepared_packages;") &&
      sql.includes("delete from public.message_translations;"),
    "all cached semantic results must be invalidated",
  );
  assert(
    sql.includes("check (cache_contract_version = 'semantic-fidelity-v5')"),
    "stored translations must identify the v5 contract",
  );
});

Deno.test("semantic-consensus migration replaces one-review cache entries", async () => {
  const sql = (await Deno.readTextFile(semanticConsensusMigrationUrl))
    .replace(/--.*$/gm, "")
    .replace(/\s+/g, " ")
    .replace(/\(\s+/g, "(")
    .replace(/\s+\)/g, ")")
    .trim()
    .toLowerCase();
  const edgeFunction = await Deno.readTextFile(edgeFunctionUrl);

  assert(
    sql.match(/p_cache_contract_version <> 'semantic-consensus-v6'/g)
      ?.length === 2,
    "both completion paths must reject one-review translations",
  );
  assert(
    sql.includes("delete from public.message_preparation_jobs") &&
      sql.includes("where status in ('processing', 'ready')"),
    "ready and in-flight variants must regenerate with audit consensus",
  );
  assert(
    sql.includes("delete from public.message_prepared_packages;") &&
      sql.includes("delete from public.message_translations;"),
    "all one-review semantic results must be invalidated",
  );
  assert(
    sql.includes("check (cache_contract_version = 'semantic-consensus-v6')"),
    "stored translations must identify the v6 contract",
  );
  assert(
    !edgeFunction.includes(
      'const CACHE_CONTRACT_VERSION = "semantic-consensus-v6";',
    ),
    "the provider must not continue writing the superseded v6 contract",
  );
});

Deno.test("semantic-audit-pivot migration replaces localized audit cache entries", async () => {
  const sql = (await Deno.readTextFile(semanticAuditPivotMigrationUrl))
    .replace(/--.*$/gm, "")
    .replace(/\s+/g, " ")
    .replace(/\(\s+/g, "(")
    .replace(/\s+\)/g, ")")
    .trim()
    .toLowerCase();
  const edgeFunction = await Deno.readTextFile(edgeFunctionUrl);

  assert(
    sql.match(/p_cache_contract_version <> 'semantic-audit-pivot-v7'/g)
      ?.length === 2,
    "both completion paths must reject localized semantic-audit results",
  );
  assert(
    sql.includes("delete from public.message_preparation_jobs") &&
      sql.includes("where status in ('processing', 'ready')"),
    "ready and in-flight variants must regenerate with the stable audit pivot",
  );
  assert(
    sql.includes("delete from public.message_prepared_packages;") &&
      sql.includes("delete from public.message_translations;"),
    "all localized semantic-audit results must be invalidated",
  );
  assert(
    sql.includes("check (cache_contract_version = 'semantic-audit-pivot-v7')"),
    "stored translations must identify the v7 contract",
  );
  assert(
    !edgeFunction.includes(
      'const CACHE_CONTRACT_VERSION = "semantic-audit-pivot-v7";',
    ),
    "the provider must not continue writing the superseded v7 contract",
  );
});

Deno.test("source-meaning-anchor migration replaces post-candidate audit cache entries", async () => {
  const sql = (await Deno.readTextFile(sourceMeaningAnchorMigrationUrl))
    .replace(/--.*$/gm, "")
    .replace(/\s+/g, " ")
    .replace(/\(\s+/g, "(")
    .replace(/\s+\)/g, ")")
    .trim()
    .toLowerCase();
  const edgeFunction = await Deno.readTextFile(edgeFunctionUrl);

  assert(
    sql.match(/p_cache_contract_version <> 'source-meaning-anchor-v8'/g)
      ?.length === 2,
    "both completion paths must reject post-candidate source meanings",
  );
  assert(
    sql.includes("delete from public.message_preparation_jobs") &&
      sql.includes("where status in ('processing', 'ready')"),
    "ready and in-flight variants must regenerate from a candidate-blind source anchor",
  );
  assert(
    sql.includes("delete from public.message_prepared_packages;") &&
      sql.includes("delete from public.message_translations;"),
    "all post-candidate source meanings must be invalidated",
  );
  assert(
    sql.includes("check (cache_contract_version = 'source-meaning-anchor-v8')"),
    "stored translations must identify the v8 contract",
  );
  assert(
    !edgeFunction.includes(
      'const CACHE_CONTRACT_VERSION = "source-meaning-anchor-v8";',
    ),
    "the provider must not continue writing the superseded v8 contract",
  );
});

Deno.test("interface-meaning migration replaces unchecked Known Language text", async () => {
  const sql = (await Deno.readTextFile(interfaceMeaningAuditMigrationUrl))
    .replace(/--.*$/gm, "")
    .replace(/\s+/g, " ")
    .replace(/\(\s+/g, "(")
    .replace(/\s+\)/g, ")")
    .trim()
    .toLowerCase();
  const edgeFunction = await Deno.readTextFile(edgeFunctionUrl);

  assert(
    sql.match(/p_cache_contract_version <> 'interface-meaning-audit-v9'/g)
      ?.length === 2,
    "both completion paths must reject unchecked Known Language text",
  );
  assert(
    sql.includes("delete from public.message_preparation_jobs") &&
      sql.includes("where status in ('processing', 'ready')"),
    "ready and in-flight variants must regenerate with interface meaning review",
  );
  assert(
    sql.includes("delete from public.message_prepared_packages;") &&
      sql.includes("delete from public.message_translations;"),
    "all unchecked Known Language text must be invalidated",
  );
  assert(
    sql.includes(
      "check (cache_contract_version = 'interface-meaning-audit-v9')",
    ),
    "stored translations must identify the v9 contract",
  );
  assert(
    !edgeFunction.includes(
      'const CACHE_CONTRACT_VERSION = "interface-meaning-audit-v9";',
    ),
    "the provider must not continue writing the superseded v9 contract",
  );
});

Deno.test("independent-review migration replaces same-model semantic decisions", async () => {
  const sql = (await Deno.readTextFile(independentSemanticReviewMigrationUrl))
    .replace(/--.*$/gm, "")
    .replace(/\s+/g, " ")
    .replace(/\(\s+/g, "(")
    .replace(/\s+\)/g, ")")
    .trim()
    .toLowerCase();
  const edgeFunction = await Deno.readTextFile(edgeFunctionUrl);

  assert(
    sql.match(/p_cache_contract_version <> 'independent-semantic-review-v10'/g)
      ?.length === 2,
    "both completion paths must reject same-model semantic decisions",
  );
  assert(
    sql.includes("delete from public.message_preparation_jobs") &&
      sql.includes("where status in ('processing', 'ready')"),
    "ready and in-flight variants must regenerate with independent review",
  );
  assert(
    sql.includes("delete from public.message_prepared_packages;") &&
      sql.includes("delete from public.message_translations;"),
    "all same-model semantic decisions must be invalidated",
  );
  assert(
    sql.includes(
      "check (cache_contract_version = 'independent-semantic-review-v10')",
    ),
    "stored translations must identify the v10 contract",
  );
  assert(
    !edgeFunction.includes(
      'const CACHE_CONTRACT_VERSION = "independent-semantic-review-v10";',
    ),
    "the provider must not continue writing the superseded v10 contract",
  );
});

Deno.test("minimal-anchor migration replaces expanded source meanings", async () => {
  const sql = (await Deno.readTextFile(minimalSourceAnchorMigrationUrl))
    .replace(/--.*$/gm, "")
    .replace(/\s+/g, " ")
    .replace(/\(\s+/g, "(")
    .replace(/\s+\)/g, ")")
    .trim()
    .toLowerCase();
  const edgeFunction = await Deno.readTextFile(edgeFunctionUrl);

  assert(
    sql.match(/p_cache_contract_version <> 'minimal-source-anchor-v11'/g)
      ?.length === 2,
    "both completion paths must reject expanded source meanings",
  );
  assert(
    sql.includes("delete from public.message_preparation_jobs") &&
      sql.includes("where status in ('processing', 'ready')"),
    "ready and in-flight variants must regenerate from a minimal anchor",
  );
  assert(
    sql.includes("delete from public.message_prepared_packages;") &&
      sql.includes("delete from public.message_translations;"),
    "all expanded source meanings must be invalidated",
  );
  assert(
    sql.includes(
      "check (cache_contract_version = 'minimal-source-anchor-v11')",
    ),
    "stored translations must identify the v11 contract",
  );
  assert(
    edgeFunction.includes(
      'const CACHE_CONTRACT_VERSION = "minimal-source-anchor-v11";',
    ),
    "the provider and database must use the same v11 contract",
  );
});

Deno.test("completion RPCs preserve corrected source-interface text", async () => {
  const sql = (await Deno.readTextFile(migrationUrl))
    .replace(/--.*$/gm, "")
    .replace(/\s+/g, " ")
    .replace(/\(\s+/g, "(")
    .replace(/\s+\)/g, ")")
    .trim()
    .toLowerCase();

  assert(
    sql.match(
      /create or replace function public\.complete_message_translation\(/g,
    )?.length === 1,
    "the migration must replace the foreground completion validator",
  );
  assert(
    sql.match(
      /create or replace function public\.complete_message_translation_job\(/g,
    )?.length === 1,
    "the migration must replace the worker completion validator",
  );
  assert(
    !sql.includes(
      "p_source_lang = p_interface_lang and p_source_lang <> p_target_lang and p_interface_text <> btrim(v_body)",
    ) &&
      !sql.includes(
        "p_source_lang = v_job.primary_known_language and p_source_lang <> v_job.learning_language and p_interface_text <> btrim(v_message.body)",
      ),
    "translation completions must not reject a corrected interface-language line",
  );
});
