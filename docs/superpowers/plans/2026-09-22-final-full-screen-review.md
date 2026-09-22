# Final Full-Screen Review Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to run this audit task-by-task. Any confirmed repair receives its own failing regression before production code changes.

**Goal:** Verify every production Blab route against the approved warm UI, with real Alice/Bob clients, long German and Ukrainian copy, and Android text scaling through 200%.

**Architecture:** Treat this packet as an evidence-first audit. Build one route/state inventory, capture the current app without production edits, classify only reproduced inconsistencies, and stop for owner approval before any repair. A separate finding-specific implementation plan will cover only approved fixes.

**Tech Stack:** Flutter, go_router, Riverpod, local Supabase, Chrome Alice client, Android Bob client, ADB screenshots, Flutter widget regressions.

---

### Task 1: Lock the route and state inventory

**Files:**
- Modify: `tasks/ui-consistency-sweep.md`
- Create: `docs/qa/2026-09-22-ui-sweep-final/README.md`

- [ ] List every production route from `lib/app/router.dart`.
- [ ] Add the route-owned secondary states from the PRD: loading, empty, offline, error, disabled, sheets, dialogs, and media.
- [ ] Assign each state to Alice browser, Bob Android, or both.
- [ ] Mark onboarding and localization/language-engine behavior as excluded.

### Task 2: Capture the default-scale production routes

**Files:**
- Create: `docs/qa/2026-09-22-ui-sweep-final/screenshots/default/`

- [ ] Start or reuse local Supabase without resetting unrelated local data.
- [ ] Run Alice in Chrome and Bob on an isolated Android emulator against the same backend.
- [ ] Confirm both identities and their shared chat before capture.
- [ ] Capture Auth, Chats, Invite, Share image, Chat, partner profile, Translation preferences, Profile, and every Profile sub-route.
- [ ] Capture route-owned loading, empty, offline, error, disabled, sheet, dialog, and media states that are not already proven by Packet 5A or 5B.

### Task 3: Stress long copy and 200% text

**Files:**
- Create: `docs/qa/2026-09-22-ui-sweep-final/screenshots/german-200/`
- Create: `docs/qa/2026-09-22-ui-sweep-final/screenshots/ukrainian-200/`

- [ ] Switch Bob's Interface Language to German and set Android font scale to `2.0`.
- [ ] Repeat every route whose structure or controls can change under longer text.
- [ ] Switch Bob's Interface Language to Ukrainian and repeat the same matrix.
- [ ] Check clipping, overlap, unreachable actions, broken wrapping, lost hierarchy, status/navigation insets, and touch-target compression.
- [ ] Restore Android font scale to `1.0` and the account's starting Interface Language.

### Task 4: Classify findings and request design approval

**Files:**
- Modify: `docs/qa/2026-09-22-ui-sweep-final/README.md`

- [ ] Record each state as Pass, Layout issue, Contrast issue, Interaction issue, Broken, or Blocked.
- [ ] Verify every suspected issue in both the rendered app and its owning source before reporting it.
- [ ] Score accessibility, performance, appearance/theming, Android conformance, adaptivity, information architecture, interaction, trust, polish, intent fit, and operational usefulness.
- [ ] Send only confirmed inconsistencies with real-app screenshots and one recommended treatment per issue.
- [ ] Wait for owner approval before changing production UI.

### Task 5: Repair only approved findings

**Files:**
- Create: `docs/superpowers/plans/2026-09-22-final-full-screen-fixes.md` only if the review finds approved defects.

- [ ] Write a finding-specific implementation plan with exact files and behavior.
- [ ] Add one focused failing regression per approved defect and verify the expected red state.
- [ ] Apply the smallest production fix and verify each regression turns green.
- [ ] Re-capture only the repaired screens at default and stressed text sizes.

### Task 6: Final verification and handoff

**Files:**
- Modify: `docs/qa/2026-09-22-ui-sweep-final/README.md`
- Modify: `tasks/ui-consistency-sweep.md`

- [ ] Run formatting, static analysis, the complete Flutter test suite, diff checks, and the production web build.
- [ ] Run the native UI review and score every category at least 8/10.
- [ ] Send one concise real-app screenshot set for owner approval.
- [ ] After approval, commit, fetch, verify conflict-free integration, push the topic branch and `main`, and wait for all GitHub gates.
- [ ] Mark Packet 6 complete only after owner screenshot approval and green remote CI.
