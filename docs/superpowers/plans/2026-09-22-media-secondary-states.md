# Media and Secondary States Implementation Plan

**Goal:** Complete UI-consistency packet 5B by aligning the two confirmed legacy surfaces and replacing the external Share photo recipient step with the approved Chats-overview pattern.

**Architecture:** Reuse the approved warm `BlabColors` tokens, established language-list treatment, and production `ChatListTile`. Keep changes local to the Auth language picker and Share photo flow. The external-share route presents Back + **Select chat**, then the normal chat rows; selecting a chat continues to the existing photo preview and send behavior.

**Tracker:** `tasks/ui-consistency-sweep.md`

## Task 1: Lock the confirmed visual contracts

- [x] Add focused tests for the Auth language picker's warm sheet, text, and selected-row treatment.
- [x] Add focused tests for the Share photo canvas, ink, secondary text, and dividers.
- [x] Confirm the focused tests fail against the current legacy styling.

## Task 2: Apply the smallest production fixes

- [x] Replace legacy white/cool styling in the Auth language picker with the approved warm language-list treatment.
- [x] Replace legacy white/cool styling in every Share photo state with approved warm tokens.
- [x] Replace the custom Share photo recipient prompt with Back + **Select chat** and the existing Chats overview rows.
- [x] Preserve Gallery and photo preview as intentional dark media surfaces.
- [x] Preserve the existing photo preview, caption, send, and conversation-opening behavior after recipient selection.

## Task 3: Verify and review

- [x] Run focused tests, formatting, analysis, UI review, full tests, and production build.
- [x] Capture both updated screens in the real app.
- [x] Wait for explicit owner approval before committing or merging.

## Task 4: Integrate after approval

- [ ] Fetch GitHub and check for divergence/conflicts.
- [ ] Commit the approved packet.
- [ ] Push and merge to `main` using a conflict-free fast-forward path.
- [ ] Confirm remote CI and update `tasks/ui-consistency-sweep.md`.
