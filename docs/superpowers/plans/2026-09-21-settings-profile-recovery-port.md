# Settings and Profile Recovery Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the already approved settings-save and profile-load recovery behavior onto current `main` without overwriting newer localization or invite/offline work.

**Architecture:** Recreate the missing behavior from tests on a fresh branch based on current `main`. Keep current locale catalogs authoritative, add one reusable inline settings error treatment, roll failed optimistic privacy writes back to their saved value, and disable Riverpod's automatic profile retry so the existing recovery UI can settle visibly.

**Tech Stack:** Flutter, Dart, Riverpod, SharedPreferences, Flutter widget tests, Android emulator, local Supabase.

---

### Task 1: Privacy save failure recovery

**Files:**
- Modify: `test/privacy_settings_test.dart`
- Create: `test/settings_failure_feedback_test.dart`
- Modify: `lib/shared/state/privacy_settings.dart`
- Modify: `lib/features/profile/privacy_screen.dart`
- Create: `lib/shared/widgets/inline_setting_error.dart`

- [ ] **Step 1: Add failing state and UI tests**

Add a persistence writer override that throws, then assert the optimistic toggle returns to its last saved value. Add a four-locale widget test that asserts the localized failure appears directly below the settings card and no Snackbar appears.

- [ ] **Step 2: Verify the new tests fail for the missing behavior**

Run: `flutter test test/privacy_settings_test.dart test/settings_failure_feedback_test.dart`

Expected: failure because the writer cannot be overridden, the toggle remains changed, and the inline error component does not exist.

- [ ] **Step 3: Add rollback and inline feedback**

Introduce `PrivacySettingWriter`, preserve the previous loaded value before optimistic updates, restore it when persistence fails, and rethrow so the screen can render the existing localized `couldNotSavePrivacy` message below the card. Keep toggles disabled while a save is in flight.

- [ ] **Step 4: Verify privacy recovery passes**

Run: `flutter test test/privacy_settings_test.dart test/settings_failure_feedback_test.dart`

Expected: all privacy recovery tests pass in English, German, Spanish, and Ukrainian.

### Task 2: Translation-preference save failure recovery

**Files:**
- Modify: `test/translation_preferences_screen_test.dart`
- Modify: `lib/features/chat/translation_preferences_screen.dart`
- Reuse: `lib/shared/widgets/inline_setting_error.dart`

- [ ] **Step 1: Add failing tests for form and reading-script saves**

Assert a failed save restores the previous selection, shows the existing localized `couldNotSavePreference` message below the preference card, and does not use a Snackbar. Cover all four interface locales for the reading-script case.

- [ ] **Step 2: Verify the tests fail for the missing behavior**

Run: `flutter test test/translation_preferences_screen_test.dart`

Expected: failure because the current screen has no shared inline error region and does not consistently restore all failed selections.

- [ ] **Step 3: Add minimal per-setting failure state**

Track the setting currently saving and the setting that failed. Disable only the saving control, clear its previous error on retry, restore the old selection when persistence throws, and render one shared inline error below the card.

- [ ] **Step 4: Verify translation-preference recovery passes**

Run: `flutter test test/translation_preferences_screen_test.dart`

Expected: all preference tests pass with localized inline feedback and restored selections.

### Task 3: Profile load recovery

**Files:**
- Create: `test/profile_load_recovery_test.dart`
- Modify: `lib/shared/state/profile_state.dart`
- Modify: `lib/features/profile/edit_profile_screen.dart`

- [ ] **Step 1: Add the failing four-locale recovery tests**

Use a profile service that fails once and succeeds on Retry. Assert the spinner stops, the localized message and refresh action appear, and tapping Retry restores the edit form.

- [ ] **Step 2: Verify the test fails on the indefinite retry state**

Run: `flutter test test/profile_load_recovery_test.dart`

Expected: failure because automatic provider retries return the screen to loading instead of leaving the recovery state visible.

- [ ] **Step 3: Stop automatic retries and align the recovery action**

Disable automatic retry for `currentProfileProvider`. Center the localized message, use the existing muted recovery hierarchy, and add a keyed refresh-icon text action that invalidates the provider.

- [ ] **Step 4: Verify profile recovery passes**

Run: `flutter test test/profile_load_recovery_test.dart`

Expected: all locale and Retry recovery cases pass.

### Task 4: Regression and Android proof

**Files:**
- Modify: `tasks/progress.md`
- Create: `docs/qa/2026-09-21-settings-profile-recovery-port/README.md`
- Create: Android screenshots in `docs/qa/2026-09-21-settings-profile-recovery-port/screenshots/`

- [ ] **Step 1: Run automated gates**

Run: `flutter test`, `flutter analyze`, and the configured debug Android build.

Expected: the complete suite passes, analyzer reports no issues, and the APK builds.

- [ ] **Step 2: Capture the three real Android failure states**

Capture: Privacy save failure with rollback and inline copy; Translation Preferences save failure with restored selection and inline copy; Profile load failure with refresh + Retry. Use the current app catalogs and do not modify translations.

- [ ] **Step 3: Send screenshots for visual approval**

Send the actual emulator screenshots as one numbered packet and wait for owner approval before committing.

- [ ] **Step 4: Record approval and commit**

Update the tracker with the verified behavior, rerun the focused checks after cleanup, and commit only the approved port.
