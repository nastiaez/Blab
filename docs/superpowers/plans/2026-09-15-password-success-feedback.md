# Password Success Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the heavy password-success Snackbar with the approved compact light pill.

**Architecture:** Add a dedicated `showAppSuccessSnack` presenter beside the existing shared Snackbar presenter. It uses a transparent Snackbar shell for lifecycle and accessibility behavior, while a centered content-sized pill owns the passive-success visuals. Both password-success routes call the shared presenter.

**Tech Stack:** Flutter, Material 3, flutter_svg, Flutter widget tests, ARB localization.

---

### Task 1: Lock the passive-success contract

**Files:**
- Modify: `test/app_messenger_test.dart`
- Modify: `test/change_password_test.dart`

- [x] Add a widget test that calls `showAppSuccessSnack('Password updated')` and asserts a 2.5-second duration, `showCloseIcon == false`, a leading `app-success-icon`, and no trailing textual checkmark.
- [x] Update the successful password-change test to expect `Password updated` and the shared success icon.
- [x] Run `flutter test test/app_messenger_test.dart test/change_password_test.dart` and confirm failure because the success presenter does not exist yet.

### Task 2: Add the shared success surface

**Files:**
- Create: `assets/icons/check-circle - 20.svg`
- Modify: `lib/app/app_messenger.dart`
- Modify: `lib/features/profile/change_password_screen.dart`
- Modify: `lib/features/auth/reset_password_screen.dart`

- [x] Add the 20 px outlined check-circle SVG using the existing icon set's 1.25 px visual weight.
- [x] Add `showAppSuccessSnack(String message)` with a transparent Snackbar shell, explicit `showCloseIcon: false`, 2.5-second duration, swipe dismissal, and a centered `#ECE7E1` pill containing the check-circle before dark text.
- [x] Replace the two password-success `showAppSnack` calls with `showAppSuccessSnack`.
- [x] Run the focused tests and confirm they pass.

### Task 3: Remove textual checkmarks from localized copy

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_de.arb`
- Modify: `lib/l10n/app_es.arb`
- Modify: `lib/l10n/app_uk.arb`
- Regenerate: `lib/l10n/generated/app_localizations_*.dart`

- [x] Change each `passwordUpdated` value to plain localized text without `✓`.
- [x] Run `flutter gen-l10n` and the focused tests.
- [x] Confirm English, German, Spanish, and Ukrainian values contain no textual checkmark.

### Task 4: Verify and capture Android evidence

**Files:**
- Modify: `tasks/prd-blab.md`
- Modify: `tasks/tech-spec.md`
- Modify: `tasks/progress.md`

- [x] Record the approved passive-success rule in the product and technical specifications.
- [x] Run `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, and `flutter test`.
- [x] Install the exact branch on the Android emulator, verify all four interface-language strings, and capture the password-success pill.
- [x] Restore the local test account password and send the after-screenshot for owner review.
