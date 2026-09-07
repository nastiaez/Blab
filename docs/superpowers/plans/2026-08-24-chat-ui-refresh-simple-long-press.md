# Chat UI Refresh + Simple Long Press Implementation Plan

> **Status:** In progress. Phone verification is intentionally deferred until the owner reconnects the device.

**Goal:** Replace message-adjacent controls with one mode-aware long-press interaction, and complete the launch behavior for message actions, reply/edit composition, receipts, and failures.

**Architecture:** Keep message rendering as the single source of truth for the primary visible text, then pass that resolved presentation into selection actions. Selection remains screen-owned so the floating reactions, temporary second language line, and composer replacement update together. Existing translation and chat services remain responsible for remote state; the screen only coordinates presentation and user intent.

**Constraints:** Preserve the dirty shared worktree, do not commit unrelated changes, and keep Step 2.13 open until the complete real-device rubric passes.

---

### Task 1: Model message presentation and action eligibility

**Files:**
- Modify: `lib/features/chat/message_actions.dart`
- Create: `lib/features/chat/message_presentation.dart`
- Modify: `test/message_action_row_test.dart`
- Create: `test/message_presentation_test.dart`

1. Add failing tests for the Normal/Practice, own/incoming, text/caption/photo-only action matrices.
2. Add failing tests for primary visible text, authored-original availability, known-language reveal, and speakable content.
3. Implement the minimal presentation resolver and eligibility rules.
4. Run the focused tests and keep the implementation scoped to launch behavior.

### Task 2: Rebuild the long-press action row

**Files:**
- Modify: `lib/features/chat/widgets/message_action_row.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_de.arb`
- Modify: `lib/l10n/app_es.arb`
- Modify: `lib/l10n/app_uk.arb`
- Modify: generated localization files
- Modify: `test/message_action_row_test.dart`

1. Add failing layout and label tests for every action and all four interface languages.
2. Add Original and Listen states with the approved supplied icons.
3. Use equal-width columns, 16 px icons, 11 px wrapping labels, 4 px gap, and accessible tap targets.
4. Verify the row at default and enlarged text sizes.

### Task 3: Make long press control the message language state

**Files:**
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `lib/features/chat/widgets/message_learning_content.dart`
- Modify: `lib/features/chat/widgets/message_interaction_target.dart`
- Modify: `test/bubble_expand_test.dart`
- Modify: `test/word_gesture_test.dart`

1. Replace old per-message Translate, sentence-audio, and Collapse controls with failing selection-state tests.
2. Reveal the known-language line only while a Practice message is selected.
3. Toggle the exact authored line from Original only while a Normal message is selected.
4. Make top controls and system Back dismiss selection on first use; preserve selection on canceled swipe and clear it on successful swipe.
5. Ensure word tap wins over bubble gestures and empty padding does nothing.

### Task 4: Complete Copy, Reply, Edit, Listen, Original, and Delete

**Files:**
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `lib/features/chat/widgets/chat_composer_input.dart`
- Modify: `lib/features/chat/widgets/message_text.dart`
- Modify: chat-screen tests

1. Add failing behavior tests proving Copy and Reply use the primary visible text.
2. Rebuild reply preview and quote styling, including exact partner name and photo fallback.
3. Rebuild edit-in-composer behavior, focus/cursor restoration, media hiding, draft persistence, and metadata order.
4. Add translation invalidation tests for meaningful edits and reuse for whitespace/emoji-only edits.
5. Replace immediate deletion and Undo with confirmation and permanent removal.
6. Use the system clipboard confirmation on current Android and the short fallback pill elsewhere.

### Task 5: Finish receipts, failures, and read privacy

**Files:**
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `lib/features/chat/state/message_reads_state.dart`
- Modify: `lib/shared/services/chat_service.dart`
- Modify: `test/message_reads_test.dart`
- Modify: relevant chat rendering tests

1. Add failing tests for clock, single gray check, double gray check, and no incoming receipt icon.
2. Add failing tests for Read receipts OFF emitting no read event.
3. Move delivery and translation failures below the bubble as text-only retry rows with stable geometry.
4. Verify failures coexist with reactions, selected state, and reply quotes.

### Task 6: Verify and hand off for phone review

**Files:**
- Modify: `tasks/progress.md`

1. Run formatting and the focused chat test set.
2. Run the complete automated suite and static checks.
3. Inspect the resulting chat states in the available local runtime and capture a screenshot if available.
4. Keep Step 2.13 in progress and record the phone pass as pending.
5. After the owner reconnects the phone, run the full Normal/Practice, direction, language, media, failure, edit, and receipt checklist before marking the step complete.
