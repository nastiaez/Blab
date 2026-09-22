# Chat Actions and Failure States Implementation Plan

**Goal:** Complete UI-consistency packet 5A by reviewing Chat actions and failure states, correcting only confirmed visual inconsistencies, and preserving all existing behavior.

**Architecture:** Reuse the approved `BlabColors`, shared list/card controls, and existing Chat interaction routes. Keep changes local to the affected widgets. Lock each visible contract with focused widget tests before changing production code.

**Tracker:** `tasks/ui-consistency-sweep.md`

## Task 1: Inventory and capture the current states

- [x] Map the widgets and existing tests for failed/pending messages, message actions, moderation, reactions, emoji, word help, and translation/correction failures.
- [x] Capture representative current states in the real app.
- [x] Record only concrete inconsistencies against the approved UI kit.

## Task 2: Lock confirmed issues with regression tests

- [x] Add focused tests for shared warm surfaces, semantic error treatment, action hierarchy, and orange-control foreground contrast where current behavior is wrong.
- [x] Run each focused test and confirm it fails for the intended visual contract.
- [x] Avoid changing tests for states that already match the approved design.

## Task 3: Apply the smallest production fixes

- [x] Replace confirmed ad hoc surfaces/colors with existing semantic tokens.
- [x] Keep destructive actions visually distinct without turning whole sheets into error states.
- [x] Preserve dark media surfaces and intentional white foregrounds.
- [x] Keep action order, copy, navigation, and business behavior unchanged.
- [x] Run focused tests after each coherent change.

## Task 4: Verify and review

- [x] Run formatting and static analysis.
- [x] Run all focused tests and the complete Flutter test suite.
- [x] Run the Impeccable detector on changed UI targets.
- [x] Build the production web target.
- [x] Verify the complete flow in the real app and capture one concise screenshot set.
- [ ] Wait for explicit owner approval before committing or merging.

## Task 5: Integrate after approval

- [ ] Fetch GitHub and check for divergence/conflicts.
- [ ] Commit the approved packet.
- [ ] Push and merge to `main` using a conflict-free fast-forward path.
- [ ] Confirm remote CI and update `tasks/ui-consistency-sweep.md`.
