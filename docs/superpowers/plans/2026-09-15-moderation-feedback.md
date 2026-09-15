# Moderation Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make report acknowledgement calm and make blocking reversible without hiding the conversation or adding a V1 blocked-people settings screen.

**Architecture:** Keep all conversations in the base chat list and derive the current partner's blocked state from the existing realtime block provider. Confirm Block with a reusable localized dialog, then replace the composer with a dedicated recovery row while blocked. Reuse the shared passive-success presenter for report/unblock and show no redundant Block Snackbar. Strengthen the existing database block helper so either direction prevents sending.

**Tech Stack:** Flutter, Riverpod, Material 3, GoRouter, Supabase/PostgreSQL RLS, ARB localization, Flutter widget tests, pgTAP.

---

### Task 1: Lock the simplified moderation contract

**Files:**
- Modify: `test/report_block_test.dart`
- Create: `test/blocked_chat_bar_test.dart`
- Create: `test/block_confirmation_dialog_test.dart`
- Create: `supabase/tests/database/block_pair_behavior.test.sql`

- [x] Add failing checks that Chats no longer filters blocked conversations.
- [x] Add failing widget checks for the persistent `You blocked Name · Unblock` composer replacement.
- [x] Add failing dialog checks for the approved copy, Cancel, and destructive Block action.
- [x] Add a failing database check proving either participant cannot send while either direction is blocked.

### Task 2: Keep blocked conversations visible

**Files:**
- Modify: `lib/features/chats/chats_screen.dart`
- Modify: `lib/shared/state/chat_list_state.dart`
- Modify: `test/report_block_test.dart`

- [x] Render `chatListProvider` directly in Chats.
- [x] Keep blocked-chat filtering only for immediate send targets such as the Android share-photo picker.
- [x] Confirm ordinary and blocked conversations remain visible.

### Task 3: Add in-chat recovery

**Files:**
- Create: `lib/features/chat/widgets/blocked_chat_bar.dart`
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_de.arb`
- Modify: `lib/l10n/app_es.arb`
- Modify: `lib/l10n/app_uk.arb`
- Regenerate: `lib/l10n/generated/app_localizations_*.dart`

- [x] Replace the composer with the blocked-state row whenever this user blocked the partner.
- [x] Wire Unblock to restore the composer and show the shared passive-success pill.
- [x] Keep history, reporting, and partner-profile access available while blocked.
- [x] Verify long names and all four locales.

### Task 4: Unify report and Block confirmation feedback

**Files:**
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `lib/features/chat/widgets/partner_profile_sheet.dart`
- Create: `lib/features/chat/widgets/block_confirmation_dialog.dart`
- Create: `test/block_confirmation_dialog_test.dart`

- [x] Present report success with the passive-success pill from both entry points.
- [x] Close the partner sheet after a successful person report so its pill is visible.
- [x] Require the approved localized confirmation before Block and keep the chat open afterward.
- [x] Show no redundant Block Snackbar; make the persistent Unblock action handle failures without losing the blocked state.

### Task 5: Enforce the block symmetrically

**Files:**
- Create: `supabase/migrations/20260915000001_symmetric_chat_blocks.sql`
- Create: `supabase/tests/database/block_pair_behavior.test.sql`

- [x] Redefine the existing message-policy helper so a block in either direction prevents both participants from sending.
- [x] Confirm unblocking restores inserts and invite claims still reuse the same canonical chat without deleting the block.

### Task 6: Verify and capture Android evidence

**Files:**
- Modify: `tasks/prd-blab.md`
- Modify: `tasks/tech-spec.md`
- Modify: `tasks/progress.md`

- [x] Record the approved visible-recovery rule and remove the stale hidden-chat requirement.
- [x] Run formatting, analysis, focused Flutter tests, the full Flutter suite, and database tests.
- [x] Verify message report, person report, Block confirmation, Cancel, Unblock, and re-invite on Android.
- [x] Check English, German, Spanish, and Ukrainian layouts.
- [ ] Restore all test blocks/reports and send the after-screenshots for owner review without committing or pushing.

### Task 7: Apply the approved visual refinement

**Files:**
- Modify: `lib/app/theme.dart`
- Modify: `lib/app/app_messenger.dart`
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `lib/features/chat/widgets/block_confirmation_dialog.dart`
- Modify: `lib/features/chat/widgets/partner_profile_sheet.dart`
- Modify: `lib/l10n/app_uk.arb`
- Modify: `test/app_messenger_test.dart`
- Modify: `test/app_localization_test.dart`
- Modify: `test/block_confirmation_dialog_test.dart`

- [x] Add failing tests for the Blab card palette, soft destructive action, adaptive 12 px pill gap, and clearer Ukrainian hate-speech label.
- [x] Apply the approved dialog colors without changing its copy or behavior.
- [x] Measure the active chat bottom surface and lift report/unblock pills above it.
- [x] Rename Ukrainian `Мова ворожнечі` to `Ненависницькі висловлювання` while keeping the stable `hate` wire value.
- [ ] Verify the updated dialog, reason sheet, report pill, and Unblock pill on Android.
