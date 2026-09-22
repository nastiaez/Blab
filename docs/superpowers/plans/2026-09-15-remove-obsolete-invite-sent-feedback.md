# Remove Obsolete Invite-Sent Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the unreachable legacy share sheet and its inaccurate “Invite sent” Snackbar while preserving the current native share flow.

**Architecture:** The production invite screen continues to own sharing through `shareInviteText`. The unused alternate share-sheet component, its dedicated tests, and its obsolete localization key are deleted so no dormant path can claim an invite was sent when Android only knows that a target app opened.

**Tech Stack:** Flutter, Android native sharing, ARB localization, Flutter tests.

---

### Task 1: Lock the copy-removal contract

**Files:**
- Modify: `test/app_localization_test.dart`

- [x] Add a test that parses every launch-locale ARB catalog and asserts the obsolete `inviteSent` key is absent.
- [x] Run `flutter test test/app_localization_test.dart` and confirm it fails because all four catalogs still contain `inviteSent`.

### Task 2: Remove the unreachable legacy surface

**Files:**
- Delete: `lib/features/invite/widgets/share_invite_sheet.dart`
- Delete: `lib/features/invite/widgets/share_targets.dart`
- Delete: `test/share_invite_sheet_test.dart`
- Delete: `test/share_targets_test.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_de.arb`
- Modify: `lib/l10n/app_es.arb`
- Modify: `lib/l10n/app_uk.arb`
- Regenerate: `lib/l10n/generated/app_localizations*.dart`

- [x] Delete the share sheet and its URI builders, whose only callers are their own tests.
- [x] Delete the obsolete widget and URI-builder tests.
- [x] Remove `inviteSent` from all four ARB catalogs and regenerate localization output.
- [x] Run `flutter test test/app_localization_test.dart` and confirm the copy-removal contract passes.

### Task 3: Verify the surviving native share flow

**Files:**
- Modify: `tasks/progress.md`

- [x] Run formatting, static analysis, the full Flutter suite, and a repository search proving no `inviteSent`, `Invite sent`, or `showShareInviteSheet` reference remains.
- [x] Open the real Android invite screen, choose a native share target, return to Blab, and confirm the screen returns quietly without success feedback.
- [x] Record the approved result and send the Android evidence for owner review.
