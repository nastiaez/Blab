# Chat Reliability Bug Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the confirmed chat reliability defects one at a time, preserving private language history, preparing translations before chat open, and making degraded states recover predictably.

**Architecture:** Treat the viewer-private language timeline and prepared viewer package as the authoritative display contract. Device state is an account-scoped recovery copy, not an empty fallback. Each task starts with a regression that reproduces one confirmed failure, applies the narrowest source fix, and runs its focused checks before the next task begins.

**Tech Stack:** Flutter/Dart 3, Riverpod, Supabase Postgres/Realtime/Storage/Edge Functions, SharedPreferences device recovery cache.

**Spec:** `tasks/prd-blab.md` US-015, US-016, US-030…US-032, US-038…US-047; FR-13, FR-14, FR-25…FR-41. Engineering contract: `tasks/tech-spec.md` Resolved Decisions 18, 21–27.

## Global Constraints

- PRD behavior wins; the original message is stored once and exact authored text remains authoritative.
- Language history, prepared translations, grammatical form, tone, unread state, reply, and edit state are private to the signed-in viewer.
- Client submits only a message ID for translation; authorization and variant selection remain server-owned.
- Interface language is never a message-translation target; all 11 supported chat languages may be a learning or primary-known language.
- Do not replace the shared dirty workspace or discard existing changes. Make only task-scoped edits and do not create commits unless the owner asks.
- Do not mark a progress step complete until its real-device rubric passes.

---

### Task 1: Keep private language history through data interruptions

**Files:**
- Modify: `lib/shared/data/local_storage_keys.dart`
- Modify: `lib/shared/services/local_chat_history_cache.dart`
- Modify: `lib/features/chat/state/unread_chat_state.dart`
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `test/local_chat_history_cache_test.dart`
- Modify: `test/chat_screen_primary_known_language_test.dart`
- Modify: `tasks/progress.md`

**Interfaces:**
- Produces: account-scoped `saveLanguageTimeline(chatId, rows)` and `loadLanguageTimeline(chatId)` recovery methods.
- Produces: a timeline provider that watches account identity, saves successful rows, restores the last good rows after a temporary fetch failure, and never converts an error into an empty timeline.

- [x] Add a failing cache test proving Alice's timeline survives restart and Bob cannot read it.
- [x] Add a failing chat test proving a timeline failure cannot retarget an old Ukrainian bubble to current German or remove its marker.
- [x] Run both tests and confirm they fail for the missing recovery behavior.
- [x] Add the account-scoped timeline key and minimal save/load implementation.
- [x] Make the provider watch the current account, save successful rows, and use only that account's cached rows on fetch failure.
- [x] Change chat readiness so an error without recovery data remains an explicit unavailable/loading state rather than an empty revision-one timeline.
- [x] Run the focused cache and chat tests, then the existing mode, marker, pagination, and translation-state checks.
- [x] Run on the connected phone: force one timeline request failure, reopen the chat, and verify every `Now learning …` marker remains; historical translated text stays assigned to Task 2 because its server access is still blocked by the obsolete cutoff.
- [x] Add a one-line Step 2.11b progress entry; keep the step in progress until the full language matrix passes.

### Task 2: Make historical translation access follow the saved language era

**Files:**
- Create: `supabase/migrations/20260829000001_historical_language_era_translation.sql`
- Modify: `supabase/tests/database/translation_security.test.sql`
- Modify: `supabase/tests/database/translation_primary_known_language.test.sql`
- Modify: `tasks/progress.md`

**Interfaces:**
- Produces: server request/completion functions that derive the applicable viewer-private language revision from the message timestamp and timeline, rather than the current single cutoff.

- [x] Add a failing database case: a message completed in Ukrainian remains requestable after the viewer switches to English and German.
- [x] Add a failing stale-result case: a pending pre-switch result cannot activate below the newer marker.
- [x] Run the database cases and confirm the obsolete cutoff causes the expected failure.
- [x] Replace cutoff eligibility with the saved per-message viewer era and validate completion against that era.
- [x] Preserve current-language behavior for new messages and preserve member authorization.
- [x] Run translation security and primary-known-language database checks.
- [ ] Verify on the phone with Ukrainian → English → German history, close/reopen, and confirm each era remains unchanged.
- [ ] Record the repair under Step 2.11b without marking the step complete before German → Spanish owner QA.

### Task 3: Process prepared translations before chat open

**Files:**
- Create: `supabase/functions/prepare-message-jobs/index.ts`
- Create: `supabase/functions/prepare-message-jobs/contract.ts`
- Create: `supabase/functions/prepare-message-jobs/contract_test.ts`
- Create: `supabase/migrations/20260829000002_message_preparation_worker.sql`
- Modify: `supabase/functions/translate-message/index.ts`
- Modify: `tasks/tech-spec.md`
- Modify: `tasks/progress.md`

**Interfaces:**
- Consumes: `message_preparation_jobs` queued rows and the existing server-owned translation contract.
- Produces: bounded, idempotent job claiming; per-viewer prepared packages; retry timing; terminal failed packages; stale-revision discard.

- [x] Add failing worker contract cases for oldest-first claiming, independent completion, retryable failure, permanent failure, and stale revision.
- [x] Run them and confirm no worker currently consumes the queue.
- [x] Add atomic job claim/lease/release functions with bounded attempts and oldest-first ordering.
- [x] Implement the server worker using the existing translation provider and completion validation, with no client plaintext or service key exposure.
- [x] Trigger work after delivery and retain a periodic recovery trigger for missed invocations.
- [x] Run contract and database checks; confirm queued jobs advance and attempts are recorded.
- [x] Device-test a 20-message burst while the recipient stays outside the chat; opening must show ready results in message order under normal conditions.
- [x] Update Decision 25/27 details and Step 2.11a progress; keep the step open until the full unread matrix passes.

### Task 4: Stop permanent translation failures from causing retry storms

**Files:**
- Modify: `lib/shared/services/message_translator.dart`
- Modify: `lib/features/chat/state/message_translations_state.dart`
- Modify: `test/message_translator_test.dart`
- Modify: `test/message_translations_state_test.dart`

**Interfaces:**
- Produces: failure classification into retryable, rate-limited, and permanent; quiet retry applies only to retryable failures.

- [ ] Add failing tests proving `translation_not_allowed` is attempted once and a transient unavailable result gets at most one quiet retry.
- [ ] Run them and confirm the permanent failure is currently retried.
- [ ] Preserve structured failure reasons and gate quiet retry by classification.
- [ ] Run focused lifecycle/translation checks and inspect phone logs to confirm one permanent failure cannot fan out across history.

### Task 5: Keep personalized grammar and tone viewer-private

**Files:**
- Create: `supabase/migrations/20260829000003_private_translation_variant_identity.sql`
- Modify: `supabase/functions/translate-message/index.ts`
- Modify: `supabase/tests/database/translation_security.test.sql`
- Modify: `test/message_translations_state_test.dart`
- Modify: `tasks/tech-spec.md`

**Interfaces:**
- Produces: translation variant identity containing viewer, language revision, source version, grammatical-form revision, and tone revision.

- [ ] Add failing cases where Alice and Bob share target languages but have different forms/tone; each must receive only their own result.
- [ ] Add a failing preference-change case proving an older prepared package is not reused.
- [ ] Run the cases and confirm the shared cache collision.
- [ ] Add viewer/preference identity to request, completion, prepared-package selection, and invalidation.
- [ ] Run database security, grammatical-form, and translation-state checks.

### Task 6: Clear all viewer-private chat state on account switch

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/features/chat/state/unread_chat_state.dart`
- Modify: `lib/features/chat/state/chat_state.dart`
- Modify: `test/chat_mode_state_test.dart`
- Modify: `test/message_reads_test.dart`

**Interfaces:**
- Produces: one account-change invalidation boundary covering language timeline, unread snapshot, translations, reply, edit, hidden messages, and mode-local interaction state.

- [ ] Add a failing Alice → Bob same-chat test proving no marker, unread divider, reply, or edit state survives.
- [ ] Run it and confirm the family caches retain private state.
- [ ] Make every private provider watch identity or invalidate it from the single account-change boundary.
- [ ] Run auth-switch, chat, read, reply, edit, and mode checks.

### Task 7: Accept legitimate names and expressive language results

**Files:**
- Modify: `supabase/functions/translate-message/contract.ts`
- Modify: `supabase/functions/translate-message/contract_test.ts`
- Modify: `lib/shared/data/translation_support.dart`
- Modify: `test/translation_support_test.dart`

**Interfaces:**
- Produces: validation that permits a same-text result only when the provider explicitly classifies it as a protected/name/language-neutral result; different-script targets still require transliteration.

- [ ] Add failing fixtures for `Heeeeeeey`, `Palllaaaaviiiiiii`, `OMG`, and a real unsupported source.
- [ ] Run them and confirm valid unchanged/name cases are rejected or misclassified.
- [ ] Add explicit provider classification and narrow validation; do not infer gender or name identity from spelling alone.
- [ ] Run contract and display checks across Latin and Cyrillic targets.

### Task 8: Allow every supported primary-known language to persist

**Files:**
- Create: `supabase/migrations/20260829000004_all_primary_known_languages.sql`
- Modify: `supabase/tests/database/translation_primary_known_language.test.sql`

**Interfaces:**
- Produces: completion validation accepting all 11 supported primary-known languages while keeping app chrome limited to four interface locales.

- [ ] Add failing completion cases for French, Dutch, Hindi, Italian, Portuguese, Tamil, and Turkish primary-known languages.
- [ ] Run them and confirm the four-locale validation rejects them.
- [ ] Separate primary-known validation from interface-locale validation.
- [ ] Run the full primary-known and security database checks.

### Task 9: Give legacy photos stable previews and offline recovery

**Files:**
- Create: `supabase/functions/backfill-message-previews/index.ts`
- Create: `supabase/migrations/20260829000005_legacy_photo_preview_backfill.sql`
- Modify: `lib/shared/services/local_chat_history_cache.dart`
- Modify: `test/local_chat_history_cache_test.dart`
- Modify: `tasks/progress.md`

**Interfaces:**
- Produces: idempotent preview generation for legacy attachments and automatic device persistence after sync.

- [ ] Add a failing legacy-photo test with no preview metadata and an offline reopen.
- [ ] Run it and confirm the old attachment has no stable fallback.
- [ ] Add bounded preview backfill without changing originals.
- [ ] Make sync cache the generated preview and keep message geometry stable while it arrives.
- [ ] Verify all existing local photos gain previews; run airplane-mode restart and reconnect replacement on the phone.
- [ ] Update Step 2.4a, marking it complete only if every device bullet passes.

### Task 10: Show a retryable chat-history error instead of an empty/stuck chat

**Files:**
- Modify: `lib/features/chat/state/chat_state.dart`
- Modify: `lib/features/chat/chat_screen.dart`
- Create: `test/chat_history_error_state_test.dart`

**Interfaces:**
- Produces: explicit initial loading, cached recovery, inline error with Retry, and successful resubscription after retry.

- [ ] Add a failing test for first fetch failure with no cache and later retry success.
- [ ] Run it and confirm the current stream stays empty/loading.
- [ ] Surface the error while retaining cached history when present; Retry must restart both initial fetch and live subscription.
- [ ] Run chat error, pagination, cache, and reconnect checks.

### Task 11: Retry read receipts after a transient connection failure

**Files:**
- Modify: `lib/features/chat/state/message_reads_state.dart`
- Modify: `test/message_reads_test.dart`

**Interfaces:**
- Produces: a deduplicated pending read set that is removed only after acknowledgement and retries on reconnection/next flush.

- [ ] Add a failing test where the first read write fails and the next flush succeeds without another visibility event.
- [ ] Run it and confirm the message ID is currently discarded.
- [ ] Retain failed IDs and reschedule with bounded backoff while respecting Read receipts OFF.
- [ ] Run read, privacy, unread-divider, and receipt presentation checks.

### Task 12: Invalidate prepared packages when form or tone changes

**Files:**
- Modify: the Task 5 variant migration if not deployed; otherwise add a new forward-only migration.
- Modify: `lib/features/chat/state/grammatical_form_preferences_state.dart`
- Modify: `test/grammatical_form_chooser_test.dart`
- Modify: `test/message_translations_state_test.dart`

**Interfaces:**
- Consumes: Task 5 viewer/preference variant identity.
- Produces: preference revision bumps that cancel stale pending work and prevent stale package hydration.

- [ ] Add failing tests for form and tone changes while old work is pending and after an old package is ready.
- [ ] Run them and confirm stale content can hydrate.
- [ ] Bump private preference identity, enqueue fresh work, and compare-and-set completion.
- [ ] Run grammatical-form, preference, and translation checks.

### Task 13: Keep unchanged correction text in stable visual runs

**Files:**
- Modify: `lib/features/chat/widgets/inline_correction_text.dart`
- Modify: `test/message_learning_content_test.dart`
- Modify: `test/inline_correction_text_test.dart`

**Interfaces:**
- Produces: adjacent unchanged segments merged without changing visible text, tap targets, or struck replacement spans.

- [ ] Keep the existing failing `Was machen machst du?` regression and add one punctuation/name case.
- [ ] Run them and confirm the fragmented unchanged runs.
- [ ] Merge adjacent equivalent runs at the presentation boundary.
- [ ] Run correction rendering, word gesture, and message learning-content checks.

### Final Verification

- [ ] Run all chat, translation, grammar, media, read, reply/edit, action, pagination, and account-switch checks.
- [ ] Run static analysis and build the Android debug app.
- [ ] Run the connected-phone matrix for language history, unopened-message burst, offline photos, unread anchor, mode switching, retry, account switch, and preference changes.
- [ ] Update `tasks/progress.md` only for rubrics actually passed on the phone.
