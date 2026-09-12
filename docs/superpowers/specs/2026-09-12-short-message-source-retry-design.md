# Short-Message Source Retry Design

## Goal

Prevent a short message from being shown untranslated when the provider returns a plausible learning-language translation but incorrectly labels the authored text as already being in the learning language.

## Decision

Add one server-side consistency check to the current translation pipeline. Do not merge the stale hotfix and do not add its provider timeout.

The rejected alternatives are:

1. Merge the old hotfix wholesale. This would overwrite newer grammatical-form, cache-v2, security, and multi-provider behavior.
2. Add the old 20-second provider timeout. This could abort legitimate long translations that the current late-cache recovery intentionally allows to finish.
3. Hardcode words such as `yes`, `hello`, or `sorry`. This would be language-specific and would miss the actual problem: inconsistent source-language metadata.

## Detection Contract

Treat a provider result as an inconsistent source classification only when all of these are true:

- The authored input is short plain-language text, not a URL, emoji-only message, code, or identifier.
- The provider claims the source language equals the requested learning language.
- The provider returns different learning-language text.
- The result lacks the complete explanation and confidence metadata required for a valid same-language correction.
- The parser would otherwise discard the returned learning-language text and restore the authored input.

This is an internal retry signal. It is never written to the cache or returned to the app.

## Runtime Flow

1. Run the normal provider request.
2. Parse and validate it with the existing translation contract.
3. If the source-classification signal is present, silently run the existing second provider attempt with stricter guidance.
4. If the second attempt is valid, cache and display it normally.
5. If the second attempt has the same inconsistency, return the existing translation failure response. The app shows its existing **Couldn’t translate · Retry** action.

No new UI label, database column, cache format, or provider deadline is introduced.

## Safety Boundaries

- At most one automatic retry.
- No hardcoded word list.
- Genuine same-language text that is returned unchanged remains `mode=none` and is not retried.
- Valid same-language corrections with explanation and confidence remain accepted.
- Long-message completion and late-cache recovery remain unchanged.
- The old `hotfix/translation-resilience` worktree and its QA screenshots/ZIP remain untouched until this fresh implementation is merged and verified.

## Verification

Add contract tests proving:

- A misclassified short English-to-Tamil result requests a retry.
- A second inconsistent attempt produces the existing failure path.
- Genuine target-language text is not retried.
- A valid short correction is not retried.
- URLs, emoji-only messages, and long text do not trigger this specific guard.
- The internal signal is absent from cached and HTTP response payloads.

Then run the complete Deno contract suite, Flutter suite, static analysis, formatting, fresh Supabase integration, and Android release build before merging.
