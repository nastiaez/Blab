# Language and Localization QA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete owner-reviewed, screenshot-backed localization QA for every user-facing Blab state, then verify all eleven Learning Languages, Primary Known Language routing, word descriptions, and audio.

**Architecture:** Run one bounded review packet at a time. Interface packets compare the same production screen/state in English, German, Spanish, and Ukrainian; language-engine packets isolate one Learning Language or Primary Known Language at a time. Findings are recorded before repair, owner feedback defines the repair scope, and each approved packet is retested, committed, and pushed before the next packet begins.

**Tech Stack:** Flutter/Dart, Flutter ARB localization, Riverpod, Supabase local development stack, Chrome client for Alice, Android emulator for Bob, Flutter widget/integration tests, Android screenshots and screen recording.

---

## File map

- `tasks/prd-blab.md`: product language-role rules and localization acceptance criteria.
- `tasks/tech-spec.md`: current Interface/Learning/Known Language implementation contract.
- `tasks/progress.md`: durable engineering progress and device acceptance gate.
- `progress.html`: owner-facing launch tracker; localization tasks stay incomplete until owner-confirmed manual evidence.
- `lib/l10n/app_en.arb`: canonical English interface copy.
- `lib/l10n/app_de.arb`: German interface copy.
- `lib/l10n/app_es.arb`: Spanish interface copy.
- `lib/l10n/app_uk.arb`: Ukrainian interface copy.
- `lib/l10n/generated/`: generated Flutter localization classes; regenerate after ARB changes.
- `lib/l10n/l10n.dart`: interface-localization helpers and safe error mapping.
- `lib/shared/state/interface_language.dart`: guest/account-scoped Interface Language persistence.
- `lib/shared/state/known_languages_state.dart`: Primary Known Language selection and fallback.
- `lib/features/profile/`: Profile and Settings surfaces for interface batches 1-4.
- `lib/features/auth/`: signup, login, and password recovery for interface batch 5.
- `lib/features/chats/` and `lib/features/invite/`: chat-list and invite states for interface batch 6.
- `lib/features/chat/`: chat controls, messages, word descriptions, language switching, and audio for batches 7 and 9-10.
- `lib/shared/services/tts_service.dart`: Learning Language word/sentence audio mapping.
- `lib/shared/services/message_translator.dart`: client translation response contract.
- `supabase/functions/translate-message/`: server translation, word-description, and correction contract.
- `test/app_localization_test.dart`: four-interface-language smoke coverage.
- `test/interface_language_state_test.dart`: Interface Language persistence and isolation.
- `test/chat_screen_primary_known_language_test.dart`: Primary Known Language translation target.
- `test/tts_service_test.dart`: all eleven Learning Language audio locale mappings.
- `test/integration/local_translation_security_test.dart`: server-authoritative translation matrix.
- `docs/qa/2026-09-14-language-localization/`: canonical screenshots, findings, and owner decisions created by this plan.

## Packet rule

Every packet uses four to eight images. Use the exact loop below and stop after Step 6 until owner feedback arrives:

1. Capture matching current-state screenshots.
2. Record `Pass`, `Wrong copy`, `English leak`, `Layout issue`, `Broken`, `Weird`, or `Blocked` for each numbered image.
3. Send the images and concise findings to the current Telegram topic.
4. Wait for owner feedback tied to screenshot numbers.
5. Write the smallest repair plan for the approved findings; do not repair unrelated observations.
6. Implement and retest the approved repair.
7. Resend only changed screenshots.
8. After explicit owner approval, commit and push that packet.

Unknown future repair code is deliberately outside this QA plan. Each repair plan is written from the observed screenshot and owner feedback, so no unapproved copy or layout decision is guessed in advance.

---

### Task 1: Align the language source of truth and tracker

**Files:**
- Modify: `tasks/prd-blab.md`
- Modify: `tasks/tech-spec.md`
- Modify: `tasks/progress.md`
- Modify: `progress.html`
- Verify: `docs/superpowers/specs/2026-09-14-language-localization-qa-design.md`

- [ ] **Step 1: Replace stale product wording**

Record the approved contract consistently:

```text
Interface Language = interface copy only.
Primary Known Language = Normal-mode translation, word descriptions, and language-learning explanations.
Learning Language = Practice-mode result plus word and sentence audio.
```

- [ ] **Step 2: Add the staged QA milestone to engineering progress**

Add one in-progress localization QA step whose completion requires all eight interface batches, eleven Learning Language packets, Primary Known Language switching, owner-reviewed screenshots, final automated gates, commit, and push.

- [ ] **Step 3: Clarify the owner tracker without marking it complete**

Update the localization task labels so they no longer ask whether word descriptions use Interface Language. Keep every `done` value false until its matching manual packet is owner-approved.

- [ ] **Step 4: Verify the written contract is consistent**

Run:

```bash
rg -n "definitions use the selected interface language|word definitions on loaded chats from locale-specific|word descriptions follow Interface Language|interface-language gloss" tasks docs/superpowers/specs progress.html
git diff --check
```

Expected: no active language-localization rule assigns word descriptions or message translations to Interface Language; historical superseded documents may remain only when clearly labelled superseded. `git diff --check` exits 0.

- [ ] **Step 5: Commit and push the approved contract**

```bash
git add tasks/prd-blab.md tasks/tech-spec.md tasks/progress.md progress.html docs/superpowers/specs/2026-09-14-language-localization-qa-design.md docs/superpowers/plans/2026-09-14-language-localization-qa.md
git commit -m "docs: align localization QA language roles"
git push origin feat/localization
```

Expected: the branch is clean and tracks `origin/feat/localization`.

---

### Task 2: Create the evidence and findings ledger

**Files:**
- Create: `docs/qa/2026-09-14-language-localization/README.md`
- Create: `docs/qa/2026-09-14-language-localization/findings.md`
- Create: `docs/qa/2026-09-14-language-localization/screenshots/.gitkeep`

- [ ] **Step 1: Create the QA record header**

Use this exact structure:

```markdown
# Language and localization QA

## Language contract
- Interface Language: interface copy only.
- Primary Known Language: Normal translations, word descriptions, learning explanations.
- Learning Language: Practice results and learning-language audio.

## Clients
- Alice: Chrome, local backend.
- Bob: Android emulator, local backend.

## Review packets
| Packet | Scope | Evidence | Owner status |
|---|---|---|---|
```

- [ ] **Step 2: Create the findings schema**

Use one repeated block per observation:

```markdown
### B01-EN-01
- Interface language: English
- Screen/state: Profile overview / loaded
- Client: Bob / Android
- Expected: all visible interface copy is English and fits at default text size
- Observed: recorded after capture
- Classification: Pass
- Severity: none
- Owner decision: pending review
- Follow-up: none
```

- [ ] **Step 3: Verify the ledger**

Run:

```bash
rg -n "Interface language|Screen/state|Classification|Owner decision" docs/qa/2026-09-14-language-localization/{README.md,findings.md}
git diff --check
```

Expected: both documents contain the shared identifiers and `git diff --check` exits 0.

---

### Task 3: Prepare the real local clients

**Files:**
- Read: `scripts/local_test.sh`
- Evidence: `docs/qa/2026-09-14-language-localization/README.md`

- [ ] **Step 1: Start the Android emulator**

Run:

```bash
flutter emulators --launch blab_pixel_api36
adb wait-for-device
flutter devices
```

Expected: an `emulator-*` Android device appears.

- [ ] **Step 2: Confirm the local backend and accounts**

Run:

```bash
supabase status
scripts/local_test.sh accounts
```

Expected: the local backend is running and Alice/Bob/Carol test accounts are listed.

- [ ] **Step 3: Launch Bob on Android and Alice in Chrome**

Run each command in its own long-running terminal:

```bash
scripts/local_test.sh android emulator-5554
scripts/local_test.sh web
```

Expected: Bob can sign in on Android and Alice can sign in in Chrome against the same local backend.

- [ ] **Step 4: Record client identity and dimensions**

Add the Android model/API, viewport, text-scale setting, Alice/Bob account identity, and local-backend date to the QA README. Do not include credentials.

---

### Task 4: Packet B01A - Profile overview in four interface languages

**Files:**
- Inspect: `lib/features/profile/profile_screen.dart`
- Inspect: `lib/l10n/app_{en,de,es,uk}.arb`
- Evidence: `docs/qa/2026-09-14-language-localization/screenshots/b01a-profile/`
- Record: `docs/qa/2026-09-14-language-localization/findings.md`

- [ ] **Step 1: Use one stable profile fixture**

Sign Bob into Android and keep the same display name, account type, Known Languages, and notification/privacy values for all four captures.

- [ ] **Step 2: Capture the loaded Profile overview**

For `en`, `de`, `es`, and `uk`: select the Interface Language, reopen Profile, and capture the complete Profile overview at default text size. Name images:

```text
B01A-EN-01-profile-loaded.png
B01A-DE-01-profile-loaded.png
B01A-ES-01-profile-loaded.png
B01A-UK-01-profile-loaded.png
```

- [ ] **Step 3: Record visible-copy and layout findings**

Check the profile hero, section headings, every settings row, current-language value, Known Languages content, logout, delete account, and bottom navigation. Record every English leak, awkward translation, overlap, clipping, inconsistent spacing, or unexpected missing row.

- [ ] **Step 4: Repeat the highest-risk locale at 200% text**

Use German first because it contains the longest common settings labels. Capture the full reachable screen and verify every row/action remains reachable by scrolling. If Ukrainian or Spanish has a longer failing label, use that locale for the second large-text capture. Keep this packet at six images maximum.

- [ ] **Step 5: Send Packet B01A and stop**

Send the four default-size images plus up to two large-text images with the numbered findings. Wait for owner feedback before any UI or copy repair.

---

### Task 5: Packet B01B - Interface Language selection and feedback states

**Files:**
- Inspect: `lib/features/profile/interface_language_screen.dart`
- Inspect: `lib/shared/state/interface_language.dart`
- Test: `test/interface_language_state_test.dart`
- Evidence: `docs/qa/2026-09-14-language-localization/screenshots/b01b-interface-language/`

- [ ] **Step 1: Capture the picker in all four languages**

Capture the same unmodified selection state in English, German, Spanish, and Ukrainian. Verify title, language names, selected state, Back label, and disabled Apply action.

- [ ] **Step 2: Capture change feedback**

Change English to German and capture the success feedback with Undo. Confirm the Profile row immediately shows the new language and survives app reopen.

- [ ] **Step 3: Capture save failure**

Trigger a real local save failure while the account remains signed in. Capture the localized error without exposing raw service text, then restore the backend and confirm Retry through Apply succeeds.

- [ ] **Step 4: Capture 200% text**

At 200% text size, verify the title, four language cards, and Apply action remain readable and reachable. Capture the longest visible locale.

- [ ] **Step 5: Send Packet B01B and stop**

Keep the packet at eight images maximum and wait for owner feedback before repair.

---

### Task 6: Interface packets B02-B08

**Files:**
- Inspect/modify only after owner feedback: `lib/features/profile/`, `lib/features/auth/`, `lib/features/chats/`, `lib/features/invite/`, `lib/features/chat/`, `lib/shared/widgets/`
- Modify after approved copy feedback: `lib/l10n/app_{en,de,es,uk}.arb`
- Regenerate after ARB changes: `lib/l10n/generated/`
- Evidence: `docs/qa/2026-09-14-language-localization/screenshots/b02-*` through `b08-*`

- [ ] **Step 1: B02 Known Languages and Translation Preferences**

Split into overview/selection and save/error packets. Compare the same state in all four interface languages; include `Not set`, self form, partner form, conversation tone, and long partner names.

- [ ] **Step 2: B03 Privacy, Notifications, logout, and account deletion**

Split into non-destructive settings and confirmations/destructive states. Include toggle help, permission status, failed save, logout dialog, delete warning, validation, and failure.

- [ ] **Step 3: B04 Edit Profile, Change Email, and Change Password**

Split each form into default/success and validation/service-error packets. Never show a raw backend error.

- [ ] **Step 4: B05 Signup, login, and password recovery**

Split into authentication forms, validation, account/service failures, reset request, email confirmation, and new-password states.

- [ ] **Step 5: B06 Chats and invite flow**

Split chat-list loaded/empty/loading/error/offline from invite creation/sharing and invite opening/terminal states.

- [ ] **Step 6: B07 Chat controls and message states**

Split header/menu/sheets, composer/reply/edit, delivery states, translation states, message actions, and photo/permission states. Keep matching messages and timestamps across locales.

- [ ] **Step 7: B08 Shared system and accessibility sweep**

Capture any untested banner, toast, dialog, permission, loading, empty, error, and offline state. Repeat the critical path at 200% text size and with screen-reader focus.

- [ ] **Step 8: Apply the packet loop independently**

For every sub-packet: capture current state, send four to eight images, wait for owner feedback, repair only approved findings, resend changed images, obtain explicit approval, commit, and push.

---

### Task 7: Add permanent interface-localization guardrails

**Files:**
- Modify: `test/app_localization_test.dart`
- Create: `test/interface_copy_contract_test.dart`
- Modify when findings require it: `lib/l10n/app_{en,de,es,uk}.arb`
- Regenerate: `lib/l10n/generated/`

- [ ] **Step 1: Add equal-key coverage**

Read the four ARB JSON objects, ignore metadata keys beginning with `@`, and assert German, Spanish, and Ukrainian expose exactly the English key set.

- [ ] **Step 2: Add placeholder parity coverage**

Extract ICU placeholders from each localized value and assert every locale preserves the English placeholder names for the same key.

- [ ] **Step 3: Add supported-screen copy coverage**

For every hardcoded user-facing string found by the approved packets, first add a failing test that renders the affected screen in German and proves the English text is visible; after repair, invert the assertion to require the localized value and reject the English leak.

- [ ] **Step 4: Regenerate and verify**

Run:

```bash
flutter gen-l10n
dart format test lib/l10n/generated
flutter test test/app_localization_test.dart test/interface_copy_contract_test.dart
flutter analyze
```

Expected: all focused tests pass and analysis reports no issues.

---

### Task 8: Learning Language packets L01-L11

**Files:**
- Inspect/modify after findings: `lib/features/chat/`
- Inspect/modify after findings: `lib/shared/services/tts_service.dart`
- Inspect/modify after findings: `supabase/functions/translate-message/`
- Test: `test/tts_service_test.dart`
- Test: `test/integration/local_translation_security_test.dart`
- Evidence: `docs/qa/2026-09-14-language-localization/screenshots/l01-*` through `l11-*`

- [ ] **Step 1: Use this fixed language order**

```text
L01 Dutch
L02 English
L03 French
L04 German
L05 Hindi
L06 Italian
L07 Portuguese
L08 Spanish
L09 Tamil
L10 Turkish
L11 Ukrainian
```

- [ ] **Step 2: Test the same content classes per language**

For each language, use one normal translatable sentence, one correct learning-language sentence, one clear learner mistake, and one sentence with a tappable content word. Preserve names, emoji, punctuation, and meaning.

- [ ] **Step 3: Verify viewer symmetry**

Send Alice-to-Bob and Bob-to-Alice. Confirm authors alone see correction coaching and recipients see the clean result.

- [ ] **Step 4: Verify word descriptions**

Open one content word and confirm the word, romanization where required, and definition use the current Primary Known Language rather than Interface Language.

- [ ] **Step 5: Verify word and sentence audio**

Play the word and the visible Practice sentence. Record `Pass`, `Unavailable as designed`, `Wrong voice/language`, or `Failed`. Confirm unavailable audio keeps the disabled icon without dead-end copy.

- [ ] **Step 6: Send one packet and stop per Learning Language**

Each L01-L11 packet contains no more than eight images plus the non-visual audio result. Wait for owner feedback and close that language before starting the next.

---

### Task 9: Primary Known Language routing and switching matrix

**Files:**
- Modify after findings: `lib/shared/state/known_languages_state.dart`
- Modify after findings: `lib/features/chat/chat_screen.dart`
- Modify after findings: `lib/features/chat/state/message_translations_state.dart`
- Modify after findings: `lib/shared/services/message_translator.dart`
- Modify after findings: `supabase/functions/translate-message/`
- Test: `test/chat_screen_primary_known_language_test.dart`
- Test: `test/message_translations_state_test.dart`
- Test: `test/integration/local_translation_security_test.dart`

- [ ] **Step 1: Run all non-identical target pairs systematically**

Use each of the eleven supported languages as Learning Language and each other supported language as Primary Known Language. Verify Practice output targets Learning Language and Normal unknown-language output targets Primary Known Language.

- [ ] **Step 2: Verify every Primary Known Language in the actual app**

Set each language primary in turn. For each one, confirm a Normal translation and one word description use the new primary language.

- [ ] **Step 3: Verify a live switch**

With the chat open, switch the primary from English to Ukrainian to German. Confirm Normal text and word descriptions refresh to the available correct variant, Practice remains in its Learning Language, and no prior-language gloss remains visible.

- [ ] **Step 4: Verify Interface Language isolation**

Keep Primary Known Language fixed and switch Interface Language through all four locales. Confirm interface copy changes while sentence translations, word descriptions, and audio remain unchanged.

- [ ] **Step 5: Verify account isolation**

Switch Bob to Alice and back. Confirm neither account inherits the other's Interface Language, Known Languages, word descriptions, or translation variants.

- [ ] **Step 6: Send focused before/after packets**

Split routing, live switching, Interface Language isolation, and account isolation into separate review packets of no more than eight images.

---

### Task 10: Final regression, evidence, and branch delivery

**Files:**
- Update: `docs/qa/2026-09-14-language-localization/README.md`
- Update: `docs/qa/2026-09-14-language-localization/findings.md`
- Update after owner confirmation: `tasks/progress.md`
- Update after owner confirmation: `progress.html`

- [ ] **Step 1: Close the findings ledger**

Every finding must be `Approved fixed`, `Approved copy`, `Accepted limitation`, or `Blocked` with a concrete reason. No item remains merely `pending review`.

- [ ] **Step 2: Run focused localization and language checks**

```bash
flutter gen-l10n
flutter test test/app_localization_test.dart test/interface_copy_contract_test.dart test/interface_language_state_test.dart test/chat_screen_primary_known_language_test.dart test/message_translations_state_test.dart test/tts_service_test.dart
```

Expected: all focused checks pass.

- [ ] **Step 3: Run the repository gates**

```bash
flutter analyze
flutter test
git diff --check
```

Expected: analysis reports no issues, the full test suite has zero failures, and `git diff --check` exits 0.

- [ ] **Step 4: Run the final Alice/Bob acceptance**

Use Alice in Chrome and Bob on Android against the same local backend. Confirm the final owner-selected interface packets, one message in each Learning Language, Primary Known Language switching, word descriptions, word/sentence audio, and account isolation. Record exact tested messages, viewers, targets, and audio availability.

- [ ] **Step 5: Request owner confirmation**

Send the final bounded evidence packets. Do not mark `localization-verify` or the engineering milestone complete until the owner explicitly confirms the manual result.

- [ ] **Step 6: Mark only confirmed tracker items complete**

After owner confirmation, update matching `done` values in `progress.html` and the localization step in `tasks/progress.md`. Keep any blocked or untested item open.

- [ ] **Step 7: Commit and push final delivery**

```bash
git add tasks progress.html lib test supabase docs/qa docs/superpowers
git commit -m "feat: complete language and localization QA"
git push origin feat/localization
git status --short --branch
```

Expected: `feat/localization` is clean and synchronized with `origin/feat/localization`.
