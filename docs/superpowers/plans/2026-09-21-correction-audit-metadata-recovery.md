# Correction Audit Metadata Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve a valid same-language correction when only its word-help token metadata is stale, repairing that metadata without rewriting the sentence.

**Architecture:** Split correction-audit parsing into a semantic candidate parser and the existing strict complete-result parser. The provider flow uses the semantic candidate, accepts complete tokens immediately, and invokes the existing immutable sentence metadata repair only when token reproduction is the sole failure.

**Tech Stack:** Deno, TypeScript, strict JSON-schema provider responses, OpenRouter/OpenAI chat completions, Flutter/Supabase local QA.

---

### Task 1: Lock the real malformed Tamil response in a parser regression

**Files:**
- Modify: `supabase/functions/translate-message/contract_test.ts`
- Modify: `supabase/functions/translate-message/contract.ts`

- [ ] **Step 1: Add a failing test containing the real provider shape**

Add a test whose `correctedText` ends in `இருக்கிறார்கள்.` while the final
token remains `இருக்கிறது`. Assert that a semantic correction candidate keeps
the corrected sentence and returns `tokens: null`, while
`parseCorrectionAuditResult` remains strict and returns `null`.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
deno test supabase/functions/translate-message/contract_test.ts --filter "stale correction tokens"
```

Expected: FAIL because `parseCorrectionAuditCandidate` does not exist.

- [ ] **Step 3: Implement semantic candidate parsing**

Add an exported `CorrectionAuditCandidate` type. Extract the existing semantic
validation into `parseCorrectionAuditCandidate(content, sourceText)`. For an
error candidate, return validated tokens when they reproduce `correctedText`,
otherwise return the valid semantic fields with `tokens: null`.
`parseCorrectionAuditResult` must delegate to the candidate parser and continue
returning `null` whenever an error candidate has no valid tokens.

- [ ] **Step 4: Run the focused parser test and verify GREEN**

Run the same filtered Deno command. Expected: PASS.

### Task 2: Recover only invalid correction metadata

**Files:**
- Modify: `supabase/functions/translate-message/index.ts`
- Modify: `supabase/functions/translate-message/provider_test.ts`

- [ ] **Step 1: Add a failing provider-flow regression**

Extend the focused-audit source contract test to require the correction audit
block to parse a semantic candidate and call `repairWordMetadata` only when a
valid correction has `tokens === null`.

- [ ] **Step 2: Run the provider test and verify RED**

Run:

```bash
deno test supabase/functions/translate-message/provider_test.ts --filter "focused audits"
```

Expected: FAIL because the audit block still treats malformed tokens as a
fatal correction-audit failure.

- [ ] **Step 3: Add the metadata-only recovery**

Update `auditSameLanguageCorrection` to:

```ts
const candidate = parseCorrectionAuditCandidate(content, text);
if (candidate === null) return null;
if (!candidate.hasError || candidate.tokens !== null) return candidate;
const repairedTokens = await repairWordMetadata(
  credential,
  candidate.correctedText,
  targetLang,
  interfaceLang,
);
return repairedTokens === null ? null : { ...candidate, tokens: repairedTokens };
```

Do not retry or alter `candidate.correctedText`.

- [ ] **Step 4: Run focused and full engine tests**

Run:

```bash
deno test --allow-env --allow-read supabase/functions/translate-message
```

Expected: every language-engine test passes.

### Task 3: Prove the exact Tamil repair and release gate

**Files:**
- Modify: `docs/qa/2026-09-14-language-localization/findings.md`
- Modify: `docs/qa/2026-09-14-language-localization/README.md`
- Create after approval: `docs/qa/2026-09-14-language-localization/screenshots/l09-tamil/*`

- [ ] **Step 1: Regenerate the exact two-user Tamil fixture**

Requeue or recreate the disposable Tamil chat and verify both viewers receive
`குழந்தைகள் நிலையத்திற்கு அருகில் இருக்கிறார்கள்.` with a French explanation,
matching French token glosses, and Latin romanization.

- [ ] **Step 2: Verify both real clients and Tamil audio**

Open Alice's browser client and Bob's Android client on the same chat. Capture
the corrected bubble, word popup, and long-press action row. Verify word and
sentence TTS dispatch `ta-IN` and complete.

- [ ] **Step 3: Run the complete gate**

Run:

```bash
flutter test --reporter compact
deno test --allow-env --allow-read supabase/functions/translate-message
flutter analyze
deno fmt --check supabase/functions/translate-message/index.ts supabase/functions/translate-message/contract.ts supabase/functions/translate-message/contract_test.ts supabase/functions/translate-message/provider_test.ts
git diff --check
flutter build apk --debug
```

Expected: all tests pass, analysis and formatting are clean, the diff check is
clean, and Android packaging exits successfully.

- [ ] **Step 4: Send the repaired screenshot packet for approval**

Report the exact correction, metadata, audio locale, job results, automated
gate counts, and any remaining limitation. Do not commit or push the repair
until the user approves the retested packet.
