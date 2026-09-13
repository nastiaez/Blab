# Translation Failure Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve valid German translations, restore local background preparation, repair stale unsupported states, and show one concise unsupported-language message.

**Architecture:** Keep the current translation and preparation pipelines. Make form auditing non-blocking only when the audit itself is unavailable, provision the existing local worker during reset, let failed in-memory entries perform a cache-only recovery lookup, and collapse author-specific unsupported copy into one localized string.

**Tech Stack:** Flutter/Dart, Riverpod, Deno/TypeScript, Supabase/PostgreSQL/Vault, Bash

---

### Task 1: Preserve a valid base translation when the form audit is unavailable

**Files:**
- Modify: `supabase/functions/translate-message/contract.ts`
- Modify: `supabase/functions/translate-message/index.ts`
- Test: `supabase/functions/translate-message/contract_test.ts`

- [ ] Add failing tests for a pure audit-resolution helper: null audit returns the unchanged base result; a no-choice audit removes alternatives; a valid required-choice audit applies alternatives; an invalid required-choice audit returns null.
- [ ] Run the focused Deno test and verify that it fails because the helper does not exist.
- [ ] Implement the helper and replace the blocking `form_audit_unavailable` branch with it.
- [ ] Run the focused and complete translation-service tests.

### Task 2: Configure the local preparation worker after every reset

**Files:**
- Modify: `scripts/local_test.sh`
- Modify: `test/ci_contract_test.dart`

- [ ] Add a failing contract assertion that the reset path configures `blab_translation_worker_url` and `blab_worker_service_role_key` through an idempotent helper.
- [ ] Run the focused Flutter test and verify the missing setup fails.
- [ ] Add a helper that derives the local service-role credential from `supabase status`, resolves the local database container, and creates or updates both Vault entries; call it after `supabase db reset`.
- [ ] Run the helper twice, verify exactly two named Vault rows, and verify a queued job records an attempt while functions are running.

### Task 3: Replace a stale client error with a stored unsupported result

**Files:**
- Modify: `lib/features/chat/state/message_translations_state.dart`
- Test: `test/message_translations_state_test.dart`

- [ ] Add a failing test that creates an error, adds a cached `sourceLang=other` result, calls `ensure` again, and expects the cache result with no additional translator call.
- [ ] Run the focused test and verify it fails because `ensure` returns early for every existing state.
- [ ] Add a cache-only repair path for matching `AsyncError` entries; keep the error when no cache row exists.
- [ ] Run translation state tests, including retry and realtime recovery coverage.

### Task 4: Use one concise unsupported-language message

**Files:**
- Modify: `tasks/prd-blab.md`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_de.arb`
- Modify: `lib/l10n/app_es.arb`
- Modify: `lib/l10n/app_uk.arb`
- Regenerate: `lib/l10n/generated/`
- Modify: `lib/features/chat/chat_screen.dart`
- Test: `test/bubble_expand_test.dart`

- [ ] Change both direction tests first to expect exactly `Blab doesn’t speak this one yet.` and no other unsupported guidance or Retry text.
- [ ] Run the focused unsupported tests and verify they fail against the current author-specific copy.
- [ ] Replace the two localized keys with one no-argument message, regenerate localization output, simplify the chat presentation, and update the PRD.
- [ ] Run the focused chat presentation tests.

### Task 5: Verify and accept in real clients

**Files:**
- Modify: `tasks/progress.md`
- Create: `docs/qa/2026-09-13-translation-failure-recovery/README.md`
- Create: real browser/emulator screenshots in the same QA directory

- [ ] Run formatting, shell syntax, static analysis, all Flutter tests, all translation-service tests, all database tests, and `git diff --check`.
- [ ] Reset the local backend, confirm the worker Vault configuration, and run Alice in the browser plus Bob on Android against the same backend.
- [ ] Send `Can you please help me?` and `Are you ready?` from Alice; verify Bob sees German translations.
- [ ] Send Chinese plus a name in both directions; verify the exact concise unsupported copy appears with no red error or Retry.
- [ ] Capture and inspect real screenshots, update the QA note and progress changelog, commit the verified scope, integrate to `main`, rerun the merged gate, push, and deliver the screenshots to the current chat.
