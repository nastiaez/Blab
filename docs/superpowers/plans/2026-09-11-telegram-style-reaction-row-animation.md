# Telegram-Style Reaction Row Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Blab's floating reaction row a Telegram-inspired anchored entrance, staggered emoji settle, fast fade exit, and reduced-motion alternative.

**Architecture:** Keep positioning and selection ownership in `ChatScreen`. Make `FloatingReactionRow` own a bounded animation timeline and an explicit visibility state; retain the selected row's geometry and message only for the 150 ms exit, then clear them.

**Tech Stack:** Flutter animation primitives, Dart timers, Flutter widget tests.

---

### Task 1: Lock the motion contract with widget tests

**Files:**
- Modify: `test/floating_reaction_row_test.dart`

- [ ] Add a test that mounts the visible row and verifies the container begins at 88% scale and reaches 100% after the entrance timeline.
- [ ] Add a test that verifies quick reactions settle at 30 ms intervals rather than appearing simultaneously.
- [ ] Add a visibility-toggle test that verifies dismissal fades for 150 ms while container scale stays at 100%.
- [ ] Add a reduced-motion test that verifies no scale or stagger is scheduled.
- [ ] Run `flutter test test/floating_reaction_row_test.dart` and verify the new tests fail because the current row has no motion contract.

### Task 2: Implement the bounded reaction-row animation

**Files:**
- Modify: `lib/features/chat/widgets/floating_reaction_row.dart`

- [ ] Convert the row to a stateful component with a 330 ms entrance timeline and 150 ms reverse duration.
- [ ] Animate container opacity and anchored scale for the first 250 ms using a softened overshoot.
- [ ] Wrap the seven reaction controls in 150 ms ease-out scale intervals starting 30 ms apart.
- [ ] On dismissal, keep scale fixed and reverse opacity only.
- [ ] Read the platform reduced-motion preference and snap to the requested visibility without spatial motion.
- [ ] Run `flutter test test/floating_reaction_row_test.dart` and verify all focused tests pass.

### Task 3: Preserve the row during its exit

**Files:**
- Modify: `lib/features/chat/chat_screen.dart`
- Test: `test/floating_reaction_row_test.dart`

- [ ] Cache the reaction-row message and geometry independently of the active message selection.
- [ ] Cancel pending cleanup when a new message is selected.
- [ ] On dismissal, hide the row immediately from hit testing, run its 150 ms fade, then clear cached geometry.
- [ ] Anchor incoming rows left and outgoing rows right.
- [ ] Run the focused reaction-row and chat-interaction tests.

### Task 4: Verify the owner-feedback build

**Files:**
- Modify: `tasks/progress.md`

- [ ] Run formatting and static analysis.
- [ ] Run the focused chat interaction suite and the full Flutter test suite.
- [ ] Build the Android debug artifact.
- [ ] Record the implementation and automated verification in Step 2.13 without marking the step complete.
- [ ] Do not commit or push until the owner reviews the animation build.
