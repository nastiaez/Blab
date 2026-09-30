# Onboarding and Authentication Refresh Implementation Plan

> **For Codex:** execute this plan test-first, in order. Do not remove the legacy auth entry until the replacement flow, callback handling, invite continuation, and Android evidence all pass.

**Goal:** Ship the approved native Flutter onboarding and authentication flow while preserving Blab's working Supabase authentication, recovery, session, locale, profile, and invite behavior.

**Architecture:** Add explicit versioned onboarding state to `profiles`, expose atomic self-only RPCs, and route every startup/auth success through one account-aware resolver. Build the new screens from a shared cream/orange component system. Keep the existing auth services and continuation mechanisms underneath until the new routes pass regression and owner review.

**Tech stack:** Flutter/Dart, Riverpod, go_router, Supabase Auth/Postgres/RLS, flutter_test, pgTAP, Android emulator/device.

**Primary contract:** `docs/superpowers/specs/2026-09-30-onboarding-auth-refresh-design.md`

---

## Stage 1 — Canonical contracts and baseline protection

### Task 1: Synchronize product and engineering source documents

**Files:**
- Modify: `tasks/prd-blab.md`
- Modify: `tasks/tech-spec.md`
- Modify: `tasks/progress.md`

1. Replace the stale combined-auth user stories and FRs with the approved 12-screen onboarding/auth journeys.
2. Record the source hierarchy: approved spec, Paper, HTML behavior, retained Flutter behavior.
3. Add a resolved engineering decision for versioned onboarding state, a central resolver, Android-first native Flutter UI, and the scoped cream/orange auth visual family.
4. Add a new in-progress onboarding/auth refresh step to `tasks/progress.md`; do not rewrite the historical Step 1.1 completion.
5. Add a changelog entry and keep all owner/device gates unchecked.
6. Run `git diff --check`.

### Task 2: Lock retained authentication behavior with contract tests

**Files:**
- Create: `test/onboarding/auth_engine_contract_test.dart`
- Modify: `test/invite_auth_flow_test.dart`
- Modify: `test/forgot_password_sent_screen_test.dart`
- Reference: `lib/shared/services/supabase_auth_service.dart`
- Reference: `lib/features/invite/invite_continuation.dart`

1. Write failing tests proving auth success must return a resolver intent rather than navigating directly to Chats.
2. Add tests for Google cancel vs typed provider failure, email existing-account mapping, password recovery continuation, and pending-invite preservation.
3. Run the focused tests and confirm each new assertion fails for the expected missing resolver behavior.
4. Add only the smallest seams/providers needed for deterministic contract tests without changing visible UI.
5. Re-run the focused tests until green.

---

## Stage 2 — Versioned persistence and resolver

### Task 3: Add onboarding schema and secure atomic operations

**Files:**
- Create: `supabase/migrations/20260930000001_versioned_onboarding.sql`
- Create: `supabase/tests/database/versioned_onboarding.test.sql`

1. Write pgTAP tests first for columns, constraints, migration preservation, version/stage defaults, self-only access, monotonic transitions, validation, idempotency, and known-language merge behavior.
2. Run the focused database test and confirm it fails because the schema/RPCs do not exist.
3. Add `onboarding_version`, `onboarding_stage`, and confirmation timestamps without changing existing names, locale, or language data.
4. Add authenticated self-only RPCs to acknowledge the introduction, confirm the display name, and confirm the translation language atomically.
5. Revoke direct bypass privileges where required while retaining older-client-compatible reads/writes outside the new setup fields.
6. Re-run the focused database test, then `supabase test db`.

### Task 4: Model onboarding state and profile service operations

**Files:**
- Create: `lib/shared/models/onboarding_stage.dart`
- Modify: `lib/shared/services/profile_service.dart`
- Modify: `lib/shared/state/profile_state.dart`
- Create: `lib/features/onboarding/state/onboarding_state.dart`
- Create: `test/onboarding/onboarding_profile_service_test.dart`
- Modify: `test/profile_service_test.dart`

1. Write failing mapping tests for every valid stage/version and defensive handling of unknown wire values.
2. Write failing provider/action tests for atomic name/language confirmations and invalidation of account-scoped profile state.
3. Extend `UserProfile` with explicit onboarding fields and exact persisted language values; do not use the client English fallback as completion evidence.
4. Add the service/RPC adapter and immutable setup state.
5. Re-run the focused tests until green.

### Task 5: Build the central asynchronous destination resolver

**Files:**
- Create: `lib/features/onboarding/state/onboarding_destination.dart`
- Create: `lib/features/onboarding/state/onboarding_resolver.dart`
- Create: `test/onboarding/onboarding_resolver_test.dart`

1. Write a complete table-driven failing test matrix for callbacks, signed-out state, onboarding version/stage, pending invite, completed accounts, offline/retry state, and account switching.
2. Confirm failures occur because the resolver does not exist.
3. Implement a pure decision function plus an async Riverpod resolver that waits for session/profile/continuation readiness.
4. Give callback-specific destinations higher priority than ordinary onboarding.
5. Add generation/account identity protection so stale account A results cannot route account B.
6. Re-run the matrix until green.

### Task 6: Integrate bootstrap and guarded routing behind a rollout switch

**Files:**
- Create: `lib/features/onboarding/bootstrap_screen.dart`
- Modify: `lib/app/router.dart`
- Modify: `lib/main.dart`
- Create: `test/onboarding/onboarding_router_test.dart`

1. Write failing router tests for cold signed-out, existing signed-in migration, interrupted name/language setup, completed account, recovery callback, invite callback, revoked session, and no wrong-screen flash.
2. Add a warm-canvas bootstrap route and the new route tree behind one local/build-time rollout switch.
3. Route every auth success and resolver refresh through the central destination result.
4. Keep the legacy `/auth` route available as rollback only; do not expose it through the new flow.
5. Re-run focused router and existing invite/recovery tests.

---

## Stage 3 — Shared native visual system and introduction

### Task 7: Add approved assets, tokens, and shared controls

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/app/theme.dart`
- Create: `lib/features/onboarding/widgets/onboarding_scaffold.dart`
- Create: `lib/features/onboarding/widgets/onboarding_top_bar.dart`
- Create: `lib/features/onboarding/widgets/primary_action_button.dart`
- Create: `lib/features/onboarding/widgets/onboarding_text_field.dart`
- Create: `lib/features/onboarding/widgets/auth_method_button.dart`
- Create: `lib/features/onboarding/widgets/inline_form_message.dart`
- Create: `lib/features/onboarding/widgets/language_choice_row.dart`
- Add approved image/icon assets under `assets/onboarding/`
- Create: `test/onboarding/onboarding_components_test.dart`

1. Read the Impeccable craft floor immediately before the first UI edit.
2. Write failing component tests for exact dimensions, states, semantics, stable error layout, safe areas, and 200% text reachability.
3. Copy only approved prototype assets; keep source aspect ratio/crop and pixel rendering where required.
4. Implement the scoped `#FAF7F2` / `#F88C5A` onboarding token family without changing unrelated chat surfaces.
5. Build shared controls and verify screens 08/09/09b can use the same button/type components.
6. Run focused widget tests and the Impeccable detector on changed UI targets.

### Task 8: Build Welcome and Learn in context

**Files:**
- Create: `lib/features/onboarding/welcome_screen.dart`
- Create: `lib/features/onboarding/learn_in_context_screen.dart`
- Create: `lib/features/onboarding/widgets/learning_dialogue.dart`
- Create: `lib/features/onboarding/state/signed_out_attempt_state.dart`
- Create: `test/onboarding/welcome_screen_test.dart`
- Create: `test/onboarding/learning_dialogue_test.dart`
- Create: `test/onboarding/learn_in_context_screen_test.dart`

1. Write failing copy/layout/navigation/language-menu tests at 360×800, 370×800, and 430×932.
2. Write deterministic fake-clock tests for every 7.05-second motion phase, loop, disposal, background/resume restart, Continue independence, audio replay, and reduced motion.
3. Implement Welcome to match the latest Paper frame and persist guest locale/explicit-choice intent.
4. Implement Learn as a route-owned state machine with the exact HTML phase timings and popup geometry.
5. Use existing on-device TTS; stop/replay rather than queue overlapping speech.
6. Capture Flutter screenshots and one full motion recording; compare against Paper/HTML before continuing.
7. Run the UI/UX reviewer and fix any category below 8/10.

---

## Stage 4 — Authentication and recovery replacement

### Task 9: Replace signup/login method and email presentation

**Files:**
- Create: `lib/features/auth/auth_method_screen.dart`
- Create: `lib/features/auth/email_auth_screen.dart`
- Modify: `lib/shared/services/supabase_auth_service.dart`
- Modify: `lib/shared/state/interface_language.dart`
- Modify: `lib/app/router.dart`
- Create: `test/onboarding/auth_method_screen_test.dart`
- Create: `test/onboarding/email_auth_screen_test.dart`
- Create: `test/onboarding/google_account_semantics_test.dart`

1. Write failing tests for both method screens, reciprocal navigation, legal links, Google loading/cancel/failure, email validation, password guidance, existing account handoff, keyboard actions, autofill hints, and retained values.
2. Split email signup from login visually while reusing existing Supabase actions.
3. Remove name collection from email signup and pass only email/password plus guest interface locale metadata.
4. Route Google results by returned profile/setup state, not by button label; preserve saved Blab names over provider metadata.
5. Synchronize explicitly chosen guest locale after Google auth without overwriting an existing account with an unmarked default.
6. Route all successes through the resolver and preserve the newest pending invite.
7. Run focused and legacy auth/invite tests, capture all four default auth screens, and complete a UI/UX review cycle.

### Task 10: Replace password recovery presentation and invalid-link handling

**Files:**
- Modify: `lib/features/auth/forgot_password_screen.dart`
- Modify: `lib/features/auth/forgot_password_sent_screen.dart`
- Modify: `lib/features/auth/reset_password_screen.dart`
- Create: `lib/features/auth/reset_link_expired_screen.dart`
- Modify: `lib/main.dart`
- Modify: `lib/app/router.dart`
- Create: `test/onboarding/password_recovery_flow_test.dart`
- Create: `test/onboarding/reset_link_classification_test.dart`

1. Write failing tests for carried email, enumeration-safe request success, resend cooldown, change email, valid recovery, weak/mismatch states, expired/malformed/used links, process restart, and safe back behavior.
2. Implement the four recovery screens with one shared illustration/action family.
3. Classify recovery callbacks before ordinary routing and clear recovery-only state after password update.
4. Preserve entered email through recoverable errors; never persist passwords.
5. Route successful password update to email login with a quiet acknowledgement.
6. Run focused recovery and existing callback tests, capture screens 07/08/09/09b, and complete a UI/UX review cycle.

---

## Stage 5 — Authenticated setup and continuation

### Task 11: Build Confirm name and Language you understand

**Files:**
- Create: `lib/features/onboarding/confirm_name_screen.dart`
- Create: `lib/features/onboarding/language_you_understand_screen.dart`
- Modify: `lib/shared/data/languages.dart`
- Modify: `lib/app/router.dart`
- Create: `test/onboarding/confirm_name_screen_test.dart`
- Create: `test/onboarding/language_you_understand_screen_test.dart`

1. Write failing tests for blank/new-email, Google proposed name, saved-name precedence, explicit confirmation, validation, inline failures, keyboard visibility, and Back-to-Learn behavior.
2. Write failing tests for the exact 11-language order, empty vs explicit preselection, single-radio semantics, disabled CTA, independent scrolling, merge-without-deletion, and retry.
3. Implement the screens using atomic service operations only; never advance locally before confirmed success.
4. Invalidate profile/known-language state after writes, then let the resolver choose invite or Chats.
5. Capture both screens at target sizes and 200% text; complete a UI/UX review cycle.

### Task 12: Finish locale, invite, lifecycle, and account-switch integration

**Files:**
- Modify: `lib/shared/state/interface_language.dart`
- Modify: `lib/features/invite/invite_continuation.dart`
- Modify: `lib/main.dart`
- Modify: `lib/app/router.dart`
- Create: `test/onboarding/onboarding_interruption_test.dart`
- Create: `test/onboarding/account_switch_onboarding_test.dart`
- Modify: `test/invite_continuation_test.dart`
- Modify: `test/invite_resolver_recovery_test.dart`

1. Write failing tests for process death at every stage/write boundary, logout/reinstall semantics, account A→B switching, revoked sessions, explicit guest locale precedence, and invite exactly-once continuation.
2. Persist only non-secret signed-out attempt state and account-scoped server setup state.
3. Cancel/ignore stale profile and resolver work on account changes.
4. Ensure callbacks and invites resume only after required setup.
5. Re-run the focused matrix plus the existing invite, interface-language, profile, and auth suites.

---

## Stage 6 — Localization, evidence, and rollout

### Task 13: Localize and harden the complete state matrix

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_de.arb`
- Modify: `lib/l10n/app_es.arb`
- Modify: `lib/l10n/app_uk.arb`
- Regenerate: `lib/l10n/generated/*`
- Modify: relevant onboarding/auth tests

1. Add all new screen, validation, loading, recovery, and accessibility strings in all four interface languages.
2. Write failing localization-contract tests before adding each missing key/state.
3. Verify German/Ukrainian wrapping, informal Ukrainian, 200% text, TalkBack order, radio semantics, and reduced motion.
4. Run the Impeccable detector once on the completed changed UI targets.
5. Run the UI/UX reviewer for the complete flow; every score must be at least 8/10.

### Task 14: Full verification and owner-review package

**Files:**
- Create: `integration_test/onboarding_auth_flow_test.dart`
- Create: `docs/qa/2026-09-30-onboarding-auth-refresh/README.md`
- Add screenshots/recording under `docs/qa/2026-09-30-onboarding-auth-refresh/`
- Modify: `tasks/progress.md`
- Modify: `progress.html` only after explicit owner confirmation

1. Add integration journeys for new email, new Google, existing signed-out, existing signed-in migration, completed account, interruption, recovery, invite, logout, reinstall, and account switching.
2. Run `dart format lib test integration_test`.
3. Run `flutter analyze`.
4. Run `flutter test`.
5. Run `supabase test db`.
6. Run `flutter build apk --debug`.
7. Install/run the exact verified APK on Android and exercise every journey.
8. Capture all 12 default screens at 370×800 and 430×932, validation/loading/error variants, 200% text states, and a complete Learn motion/reduced-motion recording.
9. Compare screenshots to Paper and motion to HTML; record explained deviations and fix all high-salience mismatches in one bounded pass.
10. Send the review build/evidence to the owner. Keep `tasks/progress.md` and `progress.html` incomplete until owner approval.

---

## Commit checkpoints

Use scoped commits after fresh verification:

1. `docs: align onboarding auth contracts`
2. `feat: add versioned onboarding persistence`
3. `feat: add onboarding destination resolver`
4. `feat: add onboarding visual foundations`
5. `feat: add welcome and learning introduction`
6. `feat: replace signup and login presentation`
7. `feat: replace password recovery presentation`
8. `feat: add name and translation language setup`
9. `test: verify onboarding auth journeys`

Do not commit unrelated dirty-worktree changes. Do not remove the legacy auth implementation until the owner accepts the replacement journey.
