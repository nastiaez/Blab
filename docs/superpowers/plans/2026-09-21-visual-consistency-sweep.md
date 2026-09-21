# Visual Consistency Sweep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the approved Blab palette and feedback-state rules to Chats, Invite, Profile, and shared controls without changing behavior.

**Architecture:** Centralize the approved palette in `BlabColors` so existing screens inherit the migration, then make small component-level corrections where colors are hard-coded. Lock the visible contract with widget tests before each production change.

**Tech Stack:** Flutter, Dart, Riverpod, Flutter widget tests

---

### Task 1: Document the approved visual system

**Files:**
- Create: `docs/design/ui-kit.md`
- Create: `docs/superpowers/specs/2026-09-21-visual-consistency-sweep-design.md`

- [ ] **Step 1: Record the approved color, surface, control, and feedback roles**
- [ ] **Step 2: Confirm the implementation scope and non-goals match the chat approval**

### Task 2: Migrate shared palette and brand controls

**Files:**
- Modify: `lib/app/theme.dart`
- Modify: `lib/shared/widgets/picker_card.dart`
- Create: `test/visual_consistency_tokens_test.dart`

- [ ] **Step 1: Write failing token and control tests**

Assert `brand == #F88C5A`, `brandPress == #F07D4B`, `appBackground == #FAF7F2`, `error == #C62828`, and that an enabled `BrandButton` renders dark label/progress ink.

- [ ] **Step 2: Run the focused test and verify it fails for the legacy palette**

Run: `flutter test test/visual_consistency_tokens_test.dart`

- [ ] **Step 3: Update the semantic tokens and brand-control foregrounds**

Change the legacy brand, pressed, canvas, and focus values; make brand-filled controls use dark warm ink.

- [ ] **Step 4: Run the focused test and verify it passes**

Run: `flutter test test/visual_consistency_tokens_test.dart`

### Task 3: Update Chats states

**Files:**
- Modify: `lib/features/chats/chats_screen.dart`
- Modify: `lib/features/chats/widgets/chat_list_tile.dart`
- Modify: `test/chat_list_typing_test.dart`
- Modify: `test/chats_error_state_test.dart`

- [ ] **Step 1: Add failing tests for unread badge contrast and semantic error color**
- [ ] **Step 2: Run the focused tests and verify the expected failures**

Run: `flutter test test/chat_list_typing_test.dart test/chats_error_state_test.dart`

- [ ] **Step 3: Use shared canvas, brand, ink, divider, and error tokens in Chats**
- [ ] **Step 4: Run the focused tests and verify they pass**

### Task 4: Update Invite and offline feedback

**Files:**
- Modify: `lib/features/invite/new_chat_screen.dart`
- Modify: `lib/features/invite/invite_resolver_screen.dart`
- Modify: `lib/shared/widgets/offline_banner.dart`
- Modify: `test/new_chat_screen_test.dart`

- [ ] **Step 1: Add failing tests for card surface, error copy, CTA contrast, and offline treatment**
- [ ] **Step 2: Run the focused Invite tests and verify the expected failures**

Run: `flutter test test/new_chat_screen_test.dart test/invite_resolver_recovery_test.dart`

- [ ] **Step 3: Apply the shared warm surface and feedback tokens**
- [ ] **Step 4: Run the focused tests and verify they pass**

### Task 5: Normalize Profile and remaining user-facing error colors

**Files:**
- Modify: `lib/features/profile/profile_screen.dart`
- Modify: `lib/features/profile/delete_account_screen.dart`
- Modify: `lib/features/profile/change_password_screen.dart`
- Modify: `lib/features/chat/partner_profile_page.dart`
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `lib/features/chat/widgets/failed_message_sheet.dart`
- Modify: `lib/features/chat/widgets/message_action_row.dart`
- Modify: `lib/features/chat/widgets/partner_report_dialog.dart`
- Modify: `lib/features/auth/widgets/password_strength.dart`
- Modify: `test/profile_localization_test.dart`

- [ ] **Step 1: Add a failing test for the red Log out confirmation action**
- [ ] **Step 2: Run the focused Profile test and verify it fails**

Run: `flutter test test/profile_localization_test.dart`

- [ ] **Step 3: Replace ad hoc user-facing reds with `BlabColors.error` and preserve neutral Log out row styling**
- [ ] **Step 4: Run affected Profile, Chat, moderation, and auth tests**

### Task 6: Verify and visually review

**Files:**
- Create: `docs/qa/2026-09-21-visual-consistency-sweep/README.md`
- Create: `docs/qa/2026-09-21-visual-consistency-sweep/screenshots/*`

- [ ] **Step 1: Format and analyze**

Run: `dart format --output=none --set-exit-if-changed lib test && flutter analyze`

- [ ] **Step 2: Run the complete automated suite**

Run: `flutter test`

- [ ] **Step 3: Build the browser target**

Run: `flutter build web`

- [ ] **Step 4: Run Impeccable's mechanical detector on changed UI files**

Run: `impeccable detect --json <changed UI targets>`

- [ ] **Step 5: Capture and inspect the required after states with one account**

Capture Chats populated/empty/loading/error and Invite ready/loading/offline/error, then compare against the saved before set.

- [ ] **Step 6: Send matched screenshots and point out each visible change**

Do not merge until the owner confirms the visual result.
