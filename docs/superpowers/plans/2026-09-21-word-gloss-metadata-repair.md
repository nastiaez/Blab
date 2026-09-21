# Word Gloss Metadata Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent copied Learning Language words from being stored as Primary Known Language word meanings while preserving already-correct sentence output.

**Architecture:** Add a conservative pure detector for multi-word token sets whose glosses all copy the learning words. When it fires, make one focused provider request that returns only token metadata for the accepted sentence, validate that the tokens reproduce the sentence exactly, and replace only the metadata. Advance the cache contract so stale copied glosses regenerate.

**Tech Stack:** Deno TypeScript, Supabase Edge Functions, PostgreSQL migrations, Flutter Android QA, local Supabase.

---

### Task 1: Lock the copied-gloss regression

**Files:**
- Modify: `supabase/functions/translate-message/contract_test.ts`
- Test: `supabase/functions/translate-message/contract_test.ts`

- [x] **Step 1: Write failing detector tests**

Add a Portuguese/French result whose content tokens are `Nós`, `nos`,
`encontramos`, `amanhã`, `no`, and `parque`, with each gloss copied from the
token. Assert that the new detector requests repair. Also assert that valid
French glosses do not request repair, a single identical cognate does not
request repair, and matching Learning/Known languages do not request repair.

- [x] **Step 2: Run the focused suite and verify RED**

Run: `deno test --allow-env supabase/functions/translate-message/contract_test.ts`

Expected: FAIL because the copied-gloss detector and focused repair contract do not exist.

### Task 2: Add the focused metadata contract

**Files:**
- Modify: `supabase/functions/translate-message/contract.ts`
- Modify: `supabase/functions/translate-message/contract_test.ts`

- [x] **Step 1: Implement the minimum detector**

Export `wordGlossMetadataNeedsRepair(result, targetLang, interfaceLang)`. It
returns true only when the languages differ, at least two content tokens are
present, and every normalized gloss equals the normalized token text or
romanization.

- [x] **Step 2: Add the repair schema, prompt, and parser**

Export a strict response schema containing only `tokens`, a prompt that names
the exact Learning and Primary Known languages and forbids changing the
accepted sentence, and a parser that reuses complete-token validation so the
returned sequence must reproduce the sentence exactly.

- [x] **Step 3: Run the focused suite and verify GREEN**

Run: `deno test --allow-env supabase/functions/translate-message/contract_test.ts`

Expected: PASS for copied-gloss detection, false-positive guards, prompt language ownership, and exact token reproduction.

### Task 3: Repair only bad word metadata in the provider flow

**Files:**
- Modify: `supabase/functions/translate-message/index.ts`
- Test: `supabase/functions/translate-message/contract_test.ts`

- [x] **Step 1: Add the focused provider call**

Call the metadata repair only after the full sentence, correction, form, and
source checks pass and the copied-gloss detector fires. Use temperature `0`,
the strict metadata schema, and the accepted translation as the only user
text. Replace only `candidate.tokens`.

- [x] **Step 2: Keep failure bounded**

If the focused call fails or returns tokens that do not reproduce the accepted
translation exactly, record `word_metadata_repair` and continue through the
existing retry/provider fallback instead of saving the suspect tokens.

- [x] **Step 3: Run the focused suite**

Run: `deno test --allow-env supabase/functions/translate-message`

Expected: every language-engine test passes.

### Task 4: Invalidate stale copied-gloss caches

**Files:**
- Create: `supabase/migrations/20260921000002_primary_known_word_metadata_cache.sql`
- Modify: `supabase/functions/translate-message/index.ts`
- Modify: `supabase/functions/translate-message/cache_migration_test.ts`

- [x] **Step 1: Write the failing cache-contract test**

Require the service and migration to agree on the next cache-contract version,
reject the prior version, replace completed/in-flight jobs before deleting old
outputs, and requeue every affected package.

- [x] **Step 2: Run the migration test and verify RED**

Run: `deno test --allow-env supabase/functions/translate-message/cache_migration_test.ts`

Expected: FAIL because the service and database still accept `complete-language-aids-v3`.

- [x] **Step 3: Implement the migration and version bump**

Advance the contract to `primary-known-word-metadata-v4`, update both completion
RPC guards and the table constraint, replace ready/processing jobs, clear stale
packages/translations, and requeue the replaced jobs.

- [x] **Step 4: Run the migration test and verify GREEN**

Run: `deno test --allow-env supabase/functions/translate-message/cache_migration_test.ts`

Expected: PASS.

### Task 5: Re-prove Portuguese and run the release gate

**Files:**
- Update after owner approval: `docs/qa/2026-09-14-language-localization/README.md`
- Update after owner approval: `docs/qa/2026-09-14-language-localization/findings.md`
- Add after owner approval: `docs/qa/2026-09-14-language-localization/screenshots/l08-portuguese/`
- Modify: `tasks/progress.md`

- [x] **Step 1: Apply the migration locally and regenerate L08**

Recreate only the disposable Portuguese fixture. Confirm all jobs are ready and
the stored `parque` token now has French `parc`, while `livraria` remains
`librairie` and both Portuguese sentences are unchanged.

- [x] **Step 2: Recheck Alice and Bob**

Verify both directions, the correction, French explanation, both word popups,
Portuguese word/sentence audio, and the exact installed APK.

- [x] **Step 3: Run the complete gate**

Run the repository's full Flutter suite, all Deno translation tests, static
analysis, migration checks, diff integrity, and Android packaging.

Expected: zero failures outside the documented environment-only skips.

- [x] **Step 4: Send repaired screenshots for owner approval**

Do not commit or push the product repair until the owner approves the retested
Portuguese packet.
