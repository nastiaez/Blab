# Short-Message Source Retry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Silently retry one inconsistent short-message source classification and fall back to Blab's existing translation failure action when the retry is also inconsistent.

**Architecture:** Keep the current provider loop, cache contract, and UI unchanged. Mark only the parser branch that discards a provider rewrite because `sourceLang` claims the target language without correction metadata, let the existing `translationNeedsRetry` gate reject that marked result, and add targeted retry guidance for the second attempt.

**Tech Stack:** Deno, TypeScript, Supabase Edge Functions, Flutter contract tests

---

### Task 1: Prove the parser gap

**Files:**
- Modify: `supabase/functions/translate-message/contract_test.ts`

- [x] **Step 1: Write the failing misclassification test**

Add a test that parses a provider response for authored text `sorry`, target language `ta`, and interface language `en`. The provider claims `sourceLang: "ta"` but returns the Tamil translation `மன்னிக்கவும்` without correction metadata. Assert that `translationNeedsRetry(result, "ta", "sorry")` is `true`.

- [x] **Step 2: Run the focused test and verify RED**

```bash
deno test --filter "misclassified short source" supabase/functions/translate-message/contract_test.ts
```

Expected: FAIL because the current parser restores `sorry` as `mode=none` and `translationNeedsRetry` returns `false`.

### Task 2: Mark and reject the inconsistent result

**Files:**
- Modify: `supabase/functions/translate-message/contract.ts`
- Test: `supabase/functions/translate-message/contract_test.ts`

- [x] **Step 1: Add the bounded candidate predicate**

```ts
const SHORT_SOURCE_RETRY_MAX_CHARS = 24;
const SHORT_PLAIN_SOURCE = /^[\p{L}\p{M}][\p{L}\p{M}\s'’-]*$/u;

function canRetrySourceClassification(text: string): boolean {
  const value = text.trim();
  return value.length > 0 &&
    value.length <= SHORT_SOURCE_RETRY_MAX_CHARS &&
    SHORT_PLAIN_SOURCE.test(value);
}
```

- [x] **Step 2: Add an internal parser signal**

Extend `TranslationResult` with `sourceClassificationConflict?: true`. In the existing unsafe same-language rewrite branch, set the signal only when `canRetrySourceClassification(text)` is true, before restoring the authored text.

- [x] **Step 3: Make the existing retry gate reject the signal**

At the start of `translationNeedsRetry`, add:

```ts
if (result.sourceClassificationConflict === true) return true;
```

The current provider loop calls this gate on both attempts. Therefore the first conflict triggers the silent retry and a second conflict leaves `result === null`, producing the existing `translation_unavailable` response.

- [x] **Step 4: Verify GREEN**

```bash
deno test --filter "misclassified short source" supabase/functions/translate-message/contract_test.ts
```

Expected: PASS.

### Task 3: Preserve legitimate short-message behavior

**Files:**
- Modify: `supabase/functions/translate-message/contract_test.ts`

- [x] **Step 1: Add separate non-regression tests**

Test that genuine Tamil returned unchanged is not retried, a complete same-language correction is not retried, and URL, emoji-only, and input longer than 24 characters do not trigger this specific guard.

- [x] **Step 2: Run the full contract suite**

```bash
deno test supabase/functions/translate-message/contract_test.ts
```

Expected: all tests pass.

### Task 4: Give the second attempt precise guidance

**Files:**
- Modify: `supabase/functions/translate-message/contract.ts`
- Modify: `supabase/functions/translate-message/index.ts`
- Test: `supabase/functions/translate-message/contract_test.ts`

- [x] **Step 1: Test generic retry guidance**

Add a failing test for `sourceClassificationRetryGuidance("ta")`. Assert that it names Tamil, asks the provider to re-detect the authored input, and contains no example word such as `sorry`, `yes`, or `hello`.

- [x] **Step 2: Implement the guidance helper**

```ts
export function sourceClassificationRetryGuidance(targetLang: string): string {
  const targetName = LANG_NAMES[targetLang] ?? targetLang;
  return ` The previous response claimed the authored input was already ${targetName} (${targetLang}) but also rewrote it without valid correction metadata. Re-detect the source language from the original authored text. If it is not truly ${targetName}, use mode=translation and return the complete ${targetName} translation.`;
}
```

- [x] **Step 3: Wire the guidance into the existing loop**

In `index.ts`, track whether the preceding candidate had `sourceClassificationConflict === true`. Append `sourceClassificationRetryGuidance(targetLang)` only to the second attempt after that conflict. Keep the existing two-attempt maximum.

- [x] **Step 4: Run contract tests and type-check**

```bash
deno test supabase/functions/translate-message/contract_test.ts
deno check supabase/functions/translate-message/index.ts
```

Expected: all tests and type-check pass.

### Task 5: Verify the application contract

**Files:**
- Verify only; no UI source changes expected

- [x] **Step 1: Run the existing failure-label tests**

```bash
flutter test test/bubble_expand_test.dart test/translation_subtitle_test.dart
```

Expected: the existing `Couldn’t translate · Retry` and retry action tests pass.

- [x] **Step 2: Run complete release gates**

```bash
deno test --allow-read supabase/functions/translate-message/automatic_forms_test.ts supabase/functions/translate-message/cache_migration_test.ts supabase/functions/translate-message/contract_test.ts
flutter test
flutter analyze
deno fmt --check supabase/functions/translate-message/contract.ts supabase/functions/translate-message/contract_test.ts supabase/functions/translate-message/index.ts
git diff --check
```

Expected: zero failures or formatting errors; the established environment-gated Flutter skips remain documented.

- [ ] **Step 3: Commit the implementation**

```bash
git add supabase/functions/translate-message/contract.ts supabase/functions/translate-message/contract_test.ts supabase/functions/translate-message/index.ts docs/superpowers/plans/2026-09-12-short-message-source-retry.md
git commit -m "fix: retry short source misclassification"
```

- [ ] **Step 4: Publish through a PR**

Push `fix/short-message-source-retry`, open a PR into `main`, and merge only after Quality, fresh Supabase integration, and Android release checks pass.
