# Incoming Message Lifecycle Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make pending incoming translations use the same timed wave, empty reshape, and text-landing motion as outgoing translations without exposing the sender's authored text.

**Architecture:** Reuse the existing `TranslatingMessageContent` state machine and feed it a dedicated neutral placeholder for incoming pending content. Keep ordering in the chat list, reduce the standalone group status to multi-message bursts, and preserve message-owned animation state so simultaneous bubbles resolve independently.

**Tech Stack:** Flutter/Dart 3, Riverpod, Flutter widget tests, Android emulator/device recording.

**Spec:** `docs/superpowers/specs/2026-09-11-incoming-message-lifecycle-parity-design.md`

---

### Task 1: Lock the incoming lifecycle contract with failing tests

**Files:**
- Modify: `test/translating_message_content_test.dart`
- Modify: `test/message_translation_lifecycle_test.dart`
- Modify: `lib/features/chat/message_translation_lifecycle.dart`

- [x] **Step 1: Add incoming timing tests**

Extend the lifecycle host with `outgoing`, custom pending content, and multiple independently resolved children. Assert that incoming content is hidden before 180 ms, the placeholder appears at 180 ms, the wave appears at 350 ms, and resolution follows clear → empty reshape → land → settled.

- [x] **Step 2: Add reduced-motion and concurrency tests**

Assert that reduced motion shows a static placeholder and swaps directly to final text. Pump two pending lifecycles, resolve only the first, and assert the second remains in its own wave state.

- [x] **Step 3: Add the group-status rule test**

Add expectations for `shouldShowPendingTranslationGroupStatus(0/1/2)` returning `false/false/true`.

- [x] **Step 4: Verify RED**

Run:

```bash
flutter test test/translating_message_content_test.dart test/message_translation_lifecycle_test.dart
```

Expected: FAIL because the incoming placeholder contract and group-status helper are not implemented.

- [x] **Step 5: Implement only the pure status helper**

Add:

```dart
bool shouldShowPendingTranslationGroupStatus(int pendingCount) =>
    pendingCount > 1;
```

- [x] **Step 6: Re-run the lifecycle-model test**

Run `flutter test test/message_translation_lifecycle_test.dart` and expect PASS.

### Task 2: Reuse the shared lifecycle for incoming bubbles

**Files:**
- Modify: `lib/features/chat/widgets/translating_message_content.dart`
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `test/translating_message_content_test.dart`
- Modify: `test/chat_screen_primary_known_language_test.dart`

- [x] **Step 1: Add a reusable placeholder**

Move the two neutral lines into `IncomingTranslationPlaceholder`, keyed as `incoming-translation-placeholder`, with line-only color `#EAE6E0` and no independent animation.

- [x] **Step 2: Route incoming pending content through the state machine**

Remove the early-return static skeleton. For eligible incoming translation, pass `IncomingTranslationPlaceholder` as `authoredContent`, keep the real translated `MessageLearningContent` as `finalContent`, and treat `holdIncomingUntilPrevious` as unresolved until older pending messages complete.

- [x] **Step 3: Preserve failure, cache, and arrival behavior**

Continue to reveal authored text only after final failure. Initial cache hits must initialize settled; the outer bubble arrival runs once for a new placeholder and does not replay at resolution.

- [x] **Step 4: Verify GREEN for motion**

Run:

```bash
flutter test test/translating_message_content_test.dart test/chat_screen_primary_known_language_test.dart
```

Expected: PASS, including incoming pending-to-final and existing chat behavior.

### Task 3: Remove single-message status and protect simultaneous ordering

**Files:**
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `test/message_translation_lifecycle_test.dart`
- Modify: `test/chat_screen_primary_known_language_test.dart`

- [x] **Step 1: Apply the group-status rule**

Insert `_PendingTranslationStatusItem` only when at least two incoming translations are pending. Preserve the existing `Translating N messages…` placement after the oldest pending item.

- [x] **Step 2: Add chat-level regression coverage**

Assert that one pending message has no `Translating…` row, while two pending messages show one accurate count and keep separate placeholder keys.

- [x] **Step 3: Run focused tests**

Run:

```bash
flutter test test/message_translation_lifecycle_test.dart test/translating_message_content_test.dart test/chat_screen_primary_known_language_test.dart
```

Expected: PASS.

### Task 4: Update project tracking and run source verification

**Files:**
- Modify: `tasks/progress.md`
- Modify: `docs/superpowers/specs/2026-09-11-incoming-message-lifecycle-parity-design.md`

- [x] **Step 1: Record the follow-up**

Add a Step 2.11 follow-up note describing incoming parity, the single-status removal, reduced-motion behavior, and automated coverage. Keep the new acceptance boxes open until device evidence is captured.

- [x] **Step 2: Format and analyze**

Run:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
git diff --check
```

Expected: all commands exit 0.

### Task 5: Device review, evidence, commit, and push

**Files:**
- Create: `docs/qa/2026-09-11-message-lifecycle-parity/README.md`
- Create: `docs/qa/2026-09-11-message-lifecycle-parity/*.png`
- Create: `docs/qa/2026-09-11-message-lifecycle-parity/*.mp4`
- Modify: `tasks/progress.md`
- Modify: `docs/superpowers/specs/2026-09-11-incoming-message-lifecycle-parity-design.md`

- [x] **Step 1: Exercise the device matrix**

On the Android emulator/device, record outgoing slow translation, incoming slow translation, two simultaneous incoming messages, and reduced motion. Confirm only placeholder lines wave, final text lands after an empty reshape, simultaneous bubbles do not reset each other, and reduced motion swaps directly.

- [x] **Step 2: Save and review evidence**

Capture pending and final stills plus one concise MP4. Inspect the frames for source-text leakage, duplicate text, shimmer outside the lines, status-row mistakes, and layout jumps.

- [x] **Step 3: Run the product review**

Score information architecture, interaction design, trust and clarity, visual polish, fit to user intent, and operational usefulness. Each score must be at least 8/10; otherwise fix and repeat one bounded device pass.

- [x] **Step 4: Mark verified acceptance criteria**

Check only the automated/device-proven acceptance boxes and record the exact evidence in the QA README and Step 2.11 follow-up.

- [x] **Step 5: Commit and push**

Run the complete verification commands again, then commit implementation, tests, tracking, and evidence with `fix: align incoming translation lifecycle`, and push `fix/message-lifecycle-parity` to `origin`.

## Self-review

- Spec coverage: fast, medium, slow, failure, cache, ordering, simultaneous messages, reduced motion, screenshots, and video all map to tasks.
- Placeholder scan: no unresolved implementation placeholders.
- Type consistency: the existing `TranslatingMessageContent` API remains the shared state-machine boundary; only the pending child and group-status rule are added.
