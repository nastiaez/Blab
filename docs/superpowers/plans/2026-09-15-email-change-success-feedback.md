# Email Change Success Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reuse Blab's passive-success pill for confirmed email changes without allowing route visits or account changes to create false success.

**Architecture:** Keep the visual treatment in the existing shared success presenter. Add a pure same-account email-change predicate, use it in the authenticated lifecycle/auth-event paths, and make both email callback routes navigation-only rather than success sources.

**Tech Stack:** Flutter, Dart, go_router, Supabase Auth, flutter_test

---

### Task 1: Define genuine email-change detection

**Files:**
- Create: `lib/app/email_change_feedback.dart`
- Create: `test/email_change_feedback_test.dart`

- [x] **Step 1: Write the failing predicate tests**

```dart
expect(isSameAccountEmailChange(previousUserId: 'u1', previousEmail: 'old@example.com', currentUserId: 'u1', currentEmail: 'new@example.com'), isTrue);
expect(isSameAccountEmailChange(previousUserId: 'u1', previousEmail: 'old@example.com', currentUserId: 'u2', currentEmail: 'new@example.com'), isFalse);
expect(isSameAccountEmailChange(previousUserId: 'u1', previousEmail: 'old@example.com', currentUserId: 'u1', currentEmail: 'old@example.com'), isFalse);
```

- [x] **Step 2: Run the focused test and verify RED**

Run: `flutter test test/email_change_feedback_test.dart`

Expected: FAIL because `isSameAccountEmailChange` does not exist.

- [x] **Step 3: Add the minimal pure predicate**

```dart
bool isSameAccountEmailChange({required String? previousUserId, required String? previousEmail, required String? currentUserId, required String? currentEmail}) {
  return previousUserId != null && previousUserId == currentUserId && previousEmail != null && currentEmail != null && previousEmail != currentEmail;
}
```

- [x] **Step 4: Re-run the focused test and verify GREEN**

Run: `flutter test test/email_change_feedback_test.dart`

Expected: PASS.

### Task 2: Remove route-based false success and announce verified changes

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app/router.dart`
- Modify: `test/app_messenger_test.dart`

- [x] **Step 1: Add a failing callback-route regression**

Add a widget test that opens `/auth/email-changed` in a signed-out test app and asserts that neither `Email changed` nor `app-success-icon` appears.

- [x] **Step 2: Run the regression and verify RED**

Run: `flutter test test/app_messenger_test.dart --plain-name 'opening the email callback route alone does not show success'`

Expected: FAIL because the route currently schedules success unconditionally.

- [x] **Step 3: Make callback routes navigation-only**

Remove both direct `showAppSnack(...emailChanged...)` calls from `router.dart`; retain session consumption/refresh and routing.

- [x] **Step 4: Present localized success from verified same-account changes**

In `main.dart`, compare the previous identity/email with the refreshed user before updating the baseline. When the predicate returns true, call:

```dart
final context = appMessengerKey.currentContext;
showAppSuccessSnackAfterNavigation(context?.l10n.emailChanged ?? 'Email changed');
```

Use the same path for eligible auth refresh events and the app-resume fallback, updating the baseline before scheduling feedback to prevent duplicates.

- [x] **Step 5: Run focused tests and verify GREEN**

Run: `flutter test test/email_change_feedback_test.dart test/app_messenger_test.dart`

Expected: PASS.

### Task 3: Document and verify the approved result

**Files:**
- Modify: `tasks/prd-blab.md`
- Modify: `tasks/tech-spec.md`
- Modify: `tasks/progress.md`

- [x] **Step 1: Update product and technical records**

Record the approved icon-first 2.5-second treatment and the rule that only a verified same-account email change may trigger it.

- [x] **Step 2: Run repository verification**

Run: `dart format lib test && flutter analyze && flutter test && git diff --check`

Expected: formatting clean, analysis clean, all tests pass, no whitespace errors.

- [x] **Step 3: Verify on Android**

Complete a genuine local email-change confirmation, capture the localized pill on Profile, restore Bob's original email, and verify that a plain callback-route opening produces no pill.

- [ ] **Step 4: Request owner visual approval**

Send the Android screenshot and wait. Do not commit or push until the owner approves the retested packet.
