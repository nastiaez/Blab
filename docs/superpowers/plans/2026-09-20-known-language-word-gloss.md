# Primary Known Language Word Gloss Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent English-biased prompt examples from overriding the viewer's Primary Known Language for tappable-word meanings.

**Architecture:** Keep the existing translation package and cache model. Repair the provider contract at its source by removing hardcoded English gloss examples and requiring named Primary Known Language glosses in both normal and focused retry prompts; prove the change with contract tests and the real L03 French/German journey.

**Tech Stack:** Deno TypeScript, Supabase Edge Functions, Flutter Android QA, local Supabase.

---

### Task 1: Lock the prompt regression

**Files:**
- Modify: `supabase/functions/translate-message/contract_test.ts`
- Test: `supabase/functions/translate-message/contract_test.ts`

- [ ] **Step 1: Write a failing contract test**

Add assertions that the French/German standard prompt and focused retry prompt explicitly request German token glosses and contain no hardcoded English `what`, `you`, `did`, or `yesterday` gloss example.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `deno test --allow-env supabase/functions/translate-message/contract_test.ts`

Expected: FAIL because the standard prompt still embeds English gloss values and the focused retry prompt omits the requested gloss language.

### Task 2: Remove the English-biased provider instruction

**Files:**
- Modify: `supabase/functions/translate-message/contract.ts`
- Test: `supabase/functions/translate-message/contract_test.ts`

- [ ] **Step 1: Implement the minimum prompt correction**

Replace the concrete token arrays in the grammatical-form example with language-neutral guidance, and require a short named Primary Known Language gloss for each content token in the focused retry prompt.

- [ ] **Step 2: Run the focused test and verify GREEN**

Run: `deno test --allow-env supabase/functions/translate-message/contract_test.ts`

Expected: PASS with no English-biased example in the French/German prompts.

### Task 3: Verify the complete language engine

**Files:**
- Modify only if findings require it: `supabase/functions/translate-message/`

- [ ] **Step 1: Run formatting and every translation-service test**

Run: `deno fmt --check supabase/functions/translate-message`

Run: `deno test --allow-env supabase/functions/translate-message`

Expected: all checks pass.

- [ ] **Step 2: Run the repository's full automated gate**

Use the repository's existing complete Flutter, translation-service, static-analysis, diff-integrity, and Android packaging commands.

Expected: zero failures outside documented environment-only skips.

### Task 4: Re-prove L03 through the real clients

**Files:**
- Update: `docs/qa/2026-09-14-language-localization/README.md`
- Update: `docs/qa/2026-09-14-language-localization/findings.md`
- Replace repaired evidence under: `docs/qa/2026-09-14-language-localization/screenshots/l03-french/`
- Update: `tasks/progress.md`

- [ ] **Step 1: Regenerate the exact French/German package**

Invalidate only the L03 prepared package for the tested message and let the local worker regenerate it with French Learning Language and German Primary Known Language.

- [ ] **Step 2: Inspect storage and Android**

Confirm the stored package identifies German as Primary Known Language and tapping `librairie` visibly shows `Buchhandlung`, with French word and sentence audio unchanged.

- [ ] **Step 3: Capture and send only repaired evidence**

Retain the canonical Android screenshot, update the L03 finding, run the final gate against that exact evidence build, and request owner approval before committing or pushing.
