# Grammatical-Form Self Routing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make grammatical-form notes use “you” for the current viewer and make **Change** open the correct viewer or partner form picker directly.

**Architecture:** Keep `subjectIsViewer` as the single ownership signal from the translated form alternative through rendering and navigation. Encode the target in the existing preferences route, consume it once in a stateful preferences screen after preferences load, and reuse the existing picker and persistence callbacks.

**Tech Stack:** Flutter, Riverpod, go_router, flutter_test, ARB localization

---

### Task 1: Lock note copy and route behavior with failing tests

**Files:**
- Modify: `test/form_correction_chat_test.dart`
- Test: `test/form_correction_chat_test.dart`

- [x] **Step 1: Change the viewer assertion to the self-specific copy**

In `automatic viewer form uses display name and Change opens preferences`, expect `Using feminine forms for you` and assert that `Using feminine forms for Alice` is absent.

- [x] **Step 2: Assert that viewer Change opens the form picker immediately**

After tapping **Change**, assert that `Translation preferences`, `Grammatical form`, `Feminine`, `Masculine`, and `Not set` are visible. This fails while the route only opens the generic page.

- [x] **Step 3: Add the partner-routing control**

For an outgoing `Did you go yesterday?` fixture, assert that the note remains `Using feminine forms for Bob`, tap **Change**, choose **Masculine**, and verify only `partnerWrites` contains `GrammaticalForm.masculine` while `ownWrites` remains empty.

- [x] **Step 4: Run the focused red tests**

Run:

```bash
flutter test test/form_correction_chat_test.dart --plain-name 'automatic viewer form uses you and Change opens own picker'
flutter test test/form_correction_chat_test.dart --plain-name 'partner note keeps the name and Change opens partner picker'
```

Expected: FAIL because the note still interpolates the viewer name and the route does not carry a target.

### Task 2: Render self-specific note copy

**Files:**
- Modify: `lib/features/chat/widgets/grammatical_form_note.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_de.arb`
- Modify: `lib/l10n/app_es.arb`
- Modify: `lib/l10n/app_uk.arb`
- Regenerate: `lib/l10n/generated/app_localizations*.dart`
- Test: `test/form_correction_chat_test.dart`

- [x] **Step 1: Select localized copy from `subjectIsViewer`**

Use `usingFeminineFormsForYou` / `usingMasculineFormsForYou` when true and the existing `{person}` messages when false.

- [x] **Step 2: Regenerate localizations**

Run:

```bash
flutter gen-l10n
```

Expected: generated localization files contain both self-specific getters.

- [x] **Step 3: Run the note-copy test**

Run:

```bash
flutter test test/form_correction_chat_test.dart --plain-name 'automatic viewer form uses you and Change opens own picker'
```

Expected: the copy assertion passes; navigation remains red until Task 3.

### Task 3: Route Change to the correct picker

**Files:**
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `lib/features/chat/translation_preferences_screen.dart`
- Modify: `lib/app/router.dart`
- Modify: `test/form_correction_chat_test.dart`
- Test: `test/translation_preferences_screen_test.dart`

- [x] **Step 1: Add the route target**

Append `subject=viewer` or `subject=partner` from `formAlternatives.subjectIsViewer`. Parse it in both the production router and test router into `initialSubjectIsViewer`.

- [x] **Step 2: Open the matching picker once**

Convert `TranslationPreferencesScreen` to `ConsumerStatefulWidget`. After the relevant preferences resolve, schedule one post-frame callback that invokes the existing `_pickForm` with either `ownForm` and the own save callback or `partnerForm` and the partner save callback. Missing/invalid targets retain the current generic page.

- [x] **Step 3: Run both routing tests**

Run:

```bash
flutter test test/form_correction_chat_test.dart --plain-name 'automatic viewer form uses you and Change opens own picker'
flutter test test/form_correction_chat_test.dart --plain-name 'partner note keeps the name and Change opens partner picker'
flutter test test/translation_preferences_screen_test.dart
```

Expected: PASS with viewer writes isolated from partner writes and vice versa.

### Task 4: Verify and capture the Android flow

**Files:**
- Modify: `docs/qa/2026-09-11-automatic-forms/README.md`
- Create: `docs/qa/2026-09-11-automatic-forms/self-routing/01-self-note-feminine.png`
- Create: `docs/qa/2026-09-11-automatic-forms/self-routing/02-change-opens-own-picker.png`
- Create: `docs/qa/2026-09-11-automatic-forms/self-routing/03-self-note-masculine.png`

- [x] **Step 1: Run focused and static verification**

```bash
flutter test test/form_correction_chat_test.dart test/translation_preferences_screen_test.dart test/form_correction_state_test.dart
flutter analyze lib/features/chat/chat_screen.dart lib/features/chat/translation_preferences_screen.dart lib/features/chat/widgets/grammatical_form_note.dart test/form_correction_chat_test.dart test/translation_preferences_screen_test.dart
dart format --output=none --set-exit-if-changed lib/features/chat/chat_screen.dart lib/features/chat/translation_preferences_screen.dart lib/features/chat/widgets/grammatical_form_note.dart test/form_correction_chat_test.dart test/translation_preferences_screen_test.dart
git diff --check
```

Expected: focused tests pass, analysis reports no issues, formatting and diff checks exit 0.

- [x] **Step 2: Build and install**

Use the existing local Android workflow:

```bash
scripts/local_test.sh android emulator-5554
```

Expected: the debug app installs and opens against the local Blab backend.

- [x] **Step 3: Capture the actual flow**

Capture: viewer-facing **for you** note; **Change** opening the form picker; masculine selection reflected in both note and sentence.

- [x] **Step 4: Run the UI review and detector**

Score the screenshots with `ui-ux-reviewer`, then run:

```bash
/Users/aswin/.codex/plugins/cache/openai-curated-remote/impeccable/4.3.1/skills/impeccable/scripts/impeccable detect --json lib/features/chat/chat_screen.dart lib/features/chat/translation_preferences_screen.dart lib/features/chat/widgets/grammatical_form_note.dart
```

Expected: every UX score is at least 8/10 and the detector reports no blocking findings.
