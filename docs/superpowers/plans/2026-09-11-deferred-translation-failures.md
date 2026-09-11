# Deferred Translation Failures Implementation Plan

> **For Codex:** Execute this plan task-by-task with red-green verification. Keep each behavioral fix isolated and rerun its focused test before moving on.

**Goal:** Resolve the two real defects behind the deferred full-suite failures, then align obsolete assertions with the current approved chat interaction contract.

**Architecture:** Preserve the existing translation pipeline and message presentation model. Fix correction propagation at both the TypeScript contract boundary and database completion boundary. Fix quoted replies by hydrating and rendering the referenced message through the same cache key and presentation rules as its parent bubble. Change tests only when production behavior is already intentional and covered by the current product contract.

**Tech Stack:** Deno/TypeScript Edge Function, PostgreSQL/Supabase migrations, Flutter/Dart/Riverpod widget tests.

---

### Task 1: Preserve corrected interface-language text

**Files:**
- Modify: `supabase/functions/translate-message/contract.ts`
- Modify: `supabase/functions/translate-message/contract_test.ts`
- Modify: `supabase/migrations/20260911000001_harden_automatic_form_cache.sql`
- Modify: `supabase/functions/translate-message/cache_migration_test.ts`

1. Keep the existing failing contract test for `What is you doing?` as the red proof.
2. Change provider normalization so a non-target source matching the interface language retains a non-empty provider correction instead of always restoring the authored input.
3. Change both foreground and worker database completion contracts to accept corrected interface text for translation mode while preserving the equality rules for `none` and same target/interface lanes.
4. Extend the static migration tests to prove both completion paths use the revised rule.
5. Run the focused contract and migration tests.

### Task 2: Render cached translations in quoted replies

**Files:**
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `test/reply_translation_preview_test.dart`

1. Use the two existing failing widget tests as the red proof: the Tamil quote is absent, and the swipe target cannot be found by its translated text.
2. Trace the referenced message cache key, language era, hydration, and `_QuotedReply` presentation inputs.
3. Correct the smallest shared-state/key mismatch so the referenced translation hydrates and renders before either preview or swipe interaction.
4. Add an assertion that the live translator remains unused when the cache contains both translations.
5. Run the reply-preview test file.

### Task 3: Align obsolete interaction assertions

**Files:**
- Modify: `test/bubble_expand_test.dart`
- Modify: `test/message_learning_content_test.dart`

1. Run each failing file independently and capture every stale expectation.
2. Confirm current production behavior against the approved compact bubble/action contract.
3. Replace outdated text/action/segmentation assertions with semantic assertions for the current behavior. Do not reintroduce removed controls or duplicate failure chrome.
4. Run both focused test files.

### Task 4: Release verification

**Files:**
- Update: `docs/qa/2026-09-11-automatic-forms/README.md` if the verified baseline changes.

1. Run all focused Deno and Flutter tests covering the changed paths.
2. Run full Deno and Flutter suites.
3. Run Deno check, Flutter analysis, formatting checks, and `git diff --check`.
4. Review the complete diff against fetched `origin/main` and request independent code review.
5. If approved and clean, commit the fixes and push the existing feature branch so PR #8 updates.
