# Automatic Forms Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close every independent-review defect in automatic grammatical forms without changing the approved product behavior.

**Architecture:** Keep shared translation rows participant-role based and free of private preferences. Apply a viewer's saved preference only on-device, persist one annotated snapshot per chat/person, and carry word metadata for both complete form renderings so either visible sentence has correct lookup data.

**Tech Stack:** Flutter/Dart 3, Riverpod, Deno/TypeScript Edge Functions, Supabase Postgres migrations, Flutter and Deno tests.

---

### Task 1: Prove every reported regression

**Files:**
- Modify: `supabase/functions/translate-message/automatic_forms_test.ts`
- Create: `supabase/functions/translate-message/cache_migration_test.ts`
- Modify: `test/automatic_form_notes_test.dart`
- Modify: `test/form_correction_state_test.dart`
- Modify: `test/form_correction_chat_test.dart`
- Modify: `test/message_learning_content_test.dart`

- [x] Add server tests proving private saved forms never enter either translation prompt and that common English plus supported non-English direct sentences produce stable author/recipient roles.
- [x] Add client tests proving an opposite viewer rebinds a stable role, clearing masculine falls back to the original provisional suggestion, and edit/delete releases the note target.
- [x] Add a chat test proving a provisional note does not write a confirmed account or partner preference.
- [x] Add rendering tests proving Normal mode keeps known authored text and masculine rendering receives masculine token metadata.
- [x] Add migration contract tests proving every legacy cache variant is invalidated, completed/in-flight preparation jobs are replaced with fresh IDs, and pre-v2 foreground/worker completions are rejected.
- [x] Run the focused tests and confirm each new regression fails for the intended reason.

### Task 2: Make shared results private-state independent

**Files:**
- Modify: `supabase/functions/translate-message/contract.ts`
- Modify: `supabase/functions/translate-message/index.ts`
- Create: `supabase/migrations/20260911000001_harden_automatic_form_cache.sql`

- [x] Keep saved form values out of every provider prompt and compute `suggestedForm` only from the affected participant's name/feminine fallback.
- [x] Normalize every generated alternative to stable `subjectRole=author|recipient` before caching.
- [x] Add conservative direct-person recognition for common first/second-person sentences across launch languages, leaving mixed or named subjects to the audit.
- [x] Purge every legacy shared/prepared cache variant, including null-alternative rows that may contain a baked private preference; replace completed/in-flight jobs with fresh IDs; and require a v2 completion contract so stale workers or foreground requests cannot repopulate the cache.
- [x] Run the focused Deno tests and confirm they pass.

### Task 3: Preserve correct lookup metadata for either form

**Files:**
- Modify: `supabase/functions/translate-message/contract.ts`
- Modify: `supabase/functions/translate-message/index.ts`
- Modify: `lib/shared/services/message_translator.dart`
- Modify: `lib/features/chat/widgets/message_learning_content.dart`
- Modify: `lib/features/chat/state/form_correction_state.dart`

- [x] Extend alternatives with full feminine and masculine token arrays whose concatenated text matches each complete rendering.
- [x] Have the grammatical audit return and validate both arrays; make the feminine array the canonical translation metadata.
- [x] Parse, serialize, bind, and select the token array matching the visible form on-device.
- [x] Run server and Flutter token/rendering tests and confirm they pass.

### Task 4: Repair preference and lifecycle semantics

**Files:**
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `lib/features/chat/state/form_correction_state.dart`
- Modify: `lib/features/chat/widgets/message_learning_content.dart`

- [x] Stop provisional name suggestions from writing confirmed profile/chat preferences.
- [x] Keep saved preferences authoritative when present; clearing restores the annotated message's original suggestion/feminine fallback.
- [x] Remove stale note targets when an annotated message is edited or deleted.
- [x] Resolve Normal's known-source bypass before form rendering.
- [x] Run focused ledger and chat tests and confirm they pass.

### Task 5: Full verification and tracker truth

**Files:**
- Modify: `tasks/progress.md`
- Modify: `docs/qa/2026-09-11-automatic-forms/README.md`

- [x] Run all translate-message Deno tests.
- [x] Run the full Flutter test suite, scoped analysis, and formatting checks.
- [x] Record the hardening evidence and keep owner/device/language-matrix gates open unless freshly proven.
- [x] Review the final diff for unrelated or destructive changes.
