# Translation Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bound translation provider calls, retry only temporary failures, isolate account-private state, refresh after tone changes, and accept all eleven primary languages server-side.

**Architecture:** Keep the existing Flutter notifier, Supabase Edge Function, and database completion contracts. Add a reusable bounded provider transport, explicit retry classification, account-keyed local privacy storage plus identity dependencies for ephemeral state, a tone-save action that bumps the existing refresh revision, and a forward SQL migration widening the two latest completion validators.

**Tech Stack:** Flutter/Dart, Riverpod, SharedPreferences, Deno/TypeScript, Supabase/PostgreSQL, pgTAP

---

### Task 1: Bound provider requests

**Files:**
- Create: `supabase/functions/translate-message/provider.ts`
- Create: `supabase/functions/translate-message/provider_test.ts`
- Modify: `supabase/functions/translate-message/index.ts`

- [x] Write a provider test that injects a fetch which completes only after its abort signal fires, then assert a one-millisecond deadline throws `ProviderFetchError("provider_timeout")`.
- [x] Run `deno test supabase/functions/translate-message/provider_test.ts` and verify the missing transport module fails first.
- [x] Implement `fetchChatCompletion` with `AbortController`, a default 20-second timer, injected fetch support, OpenRouter policy preservation, and timer cleanup in `finally`.
- [x] Route translation, interface repair, and form audit calls through the bounded helper and preserve timeout diagnostics in the existing fallback loop.
- [x] Re-run the provider and contract tests and expect zero failures.

### Task 2: Restrict automatic retries to temporary failures

**Files:**
- Modify: `lib/features/chat/state/message_translations_state.dart`
- Modify: `test/message_translations_state_test.dart`

- [x] Add tests proving `timeout` and `invoke_failed` retry automatically while `translation_not_allowed`, `translation_stale`, `invalid_message_id`, and malformed response failures do not.
- [x] Run the focused Flutter test and verify permanent failures currently cause extra calls.
- [x] Add one explicit `isAutomaticTranslationRetryAllowed` classifier and use it in `retryTransientFailures`; retain the quota timer's separate behavior.
- [x] Re-run the focused test and expect zero failures.

### Task 3: Isolate account-private state

**Files:**
- Modify: `lib/shared/data/local_storage_keys.dart`
- Modify: `lib/shared/state/privacy_settings.dart`
- Modify: `lib/features/chat/state/message_translations_state.dart`
- Modify: `lib/features/chat/state/chat_state.dart`
- Modify: `lib/features/chat/state/message_reads_state.dart`
- Modify: `lib/features/chat/state/unread_chat_state.dart`
- Modify: `lib/features/chat/state/grammatical_form_preferences_state.dart`
- Modify: `test/privacy_settings_test.dart`
- Create: `test/account_private_state_test.dart`

- [x] Add a privacy test that switches Alice to Bob and proves Bob first fails closed, then receives Bob's default while Alice's saved choice remains isolated.
- [x] Add a notifier test that populates translation, hidden-message, reply/edit, read-queue, and revision state, switches identity, and expects clean state.
- [x] Run both tests and verify the shared keys and identity-independent notifiers fail.
- [x] Key privacy storage by account/guest identity with generation guards, and make every listed ephemeral provider watch `currentUserIdProvider` before returning state.
- [x] Re-run both tests and expect zero failures.

### Task 4: Refresh translations after tone changes

**Files:**
- Modify: `lib/features/chat/state/grammatical_form_preferences_state.dart`
- Modify: `lib/features/chat/translation_preferences_screen.dart`
- Modify: `test/translation_preferences_screen_test.dart`
- Modify: `test/message_translations_state_test.dart`

- [x] Add a tone-save action test asserting the persistence call, preference invalidation, and revision increment.
- [x] Add a translation-state test asserting a revision change uses `translateFresh` rather than the ordinary cached path.
- [x] Run the focused tests and verify the revision does not currently change.
- [x] Implement the tone-save action and route the tone picker through it.
- [x] Re-run the focused tests and expect zero failures.

### Task 5: Accept every primary known language server-side

**Files:**
- Create: `supabase/migrations/20260912000001_all_primary_translation_languages.sql`
- Modify: `supabase/tests/database/translation_security.test.sql`

- [x] Add a pgTAP assertion that a versioned completion succeeds when the prepared primary-known-language lane is Hindi.
- [x] Run the database test against the pre-migration schema and verify the Hindi completion fails.
- [x] Add a forward migration replacing both current completion validators with the full eleven-language set while preserving cache-version, authorization, source-version, and form-alternative checks.
- [x] Re-run the database test and expect zero failures.

### Task 6: Verify and ship

**Files:**
- Modify: `tasks/progress.md`
- Modify: this plan's checkboxes

- [x] Run focused Flutter and Deno suites for all five gaps.
- [x] Run `flutter test`, `flutter analyze`, the complete translation Deno suite, `deno fmt --check`, the database test when available, and `git diff --check`.
- [x] Review the final diff against the approved design and confirm no unrelated changes or owner-only tracker completions.
- [x] Record the verified reliability follow-up in `tasks/progress.md` and mark this plan complete.
- [x] Commit the complete translation-reliability change and push the current branch to GitHub.
