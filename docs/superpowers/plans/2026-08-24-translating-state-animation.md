# Translating State Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved message lifecycle so translation feels like one measured transformation, with no duplicated text, a glyph-only waiting wave, correct fast/medium/slow branches, and safe failure/reduced-motion behavior.

**Architecture:** Keep remote translation ownership in `MessageTranslationsNotifier`, add a small pure lifecycle model for eligibility and branch selection, and render motion in a focused chat widget that receives authored and final content. The transition widget uses the real laid-out child for geometry, keeps metadata outside the animated region, and exposes explicit phases for deterministic widget tests.

**Tech Stack:** Flutter/Dart 3, Riverpod, Supabase Edge Functions, Flutter widget tests, Deno contract tests.

**Spec:** `docs/superpowers/specs/2026-08-12-translating-state-animation-design.md`

## Global Constraints

- Normal outgoing messages never enter translation/correction motion.
- Practice outgoing motion starts only after delivery; pending/failed delivery never waves.
- Waiting wave starts at 350 ms and affects rendered glyphs/emoji only, never the bubble, timestamp, or receipts.
- Resolve phases are sequential: clear 120 ms, reshape 150 ms, land at most 220 ms.
- Incoming Practice content is held until final output; captioned photos are held atomically.
- Matching cached results render immediately with no request or replayed motion.
- Reduced motion removes arrival, wave, clear, reshape, and land motion.
- One quiet language retry must finish or fail within 10 seconds total.
- Existing long-press, word-tap, reply, reaction, edit, delete, and delivery affordances remain available.
- This shared working tree already contains owner changes; execute without creating commits or moving work to a separate tree.

---

### Task 1: Translation eligibility and lifecycle branch model

**Files:**
- Create: `lib/features/chat/message_translation_lifecycle.dart`
- Test: `test/message_translation_lifecycle_test.dart`
- Modify: `supabase/functions/translate-message/contract.ts`
- Test: `supabase/functions/translate-message/contract_test.ts`

**Interfaces:**
- Produces `bool containsMeaningBearingText(String text)` for client request gating.
- Produces `TranslationSpeedBranch translationSpeedBranch(Duration elapsed)` with `fast`, `medium`, and `slow` results at the exact 180/350 ms boundaries.
- Produces provider guidance that preserves emoji, URLs, mentions, hashtags, code, names, and numbers while translating surrounding language.

- [ ] Write failing Dart tests proving protected-only emoji/URL/mention/hashtag/code/number messages are ineligible, mixed text remains eligible, and 179/180/349/350 ms select the correct branches.
- [ ] Run `flutter test test/message_translation_lifecycle_test.dart` and confirm the missing model fails.
- [ ] Implement the pure eligibility and speed-branch helpers.
- [ ] Run the focused Dart test and confirm it passes.
- [ ] Add failing Deno assertions for the complete protected-content and mechanical-fix prompt contract.
- [ ] Run `deno test supabase/functions/translate-message/contract_test.ts` and confirm the new assertions fail for the missing prompt rules.
- [ ] Extend the provider contract with the exact protected-content and silent-mechanical-fix rules.
- [ ] Run the Deno contract test and confirm it passes.

### Task 2: One quiet retry and ten-second lifecycle cap

**Files:**
- Modify: `lib/features/chat/state/message_translations_state.dart`
- Test: `test/message_translations_state_test.dart`

**Interfaces:**
- `MessageTranslationsNotifier.ensure(...)` still exposes the existing `AsyncLoading → AsyncData/AsyncError` contract.
- A failed live request receives one immediate quiet retry inside a shared 10-second deadline.
- `retry(...)` starts a fresh two-attempt lifecycle.

- [ ] Add failing tests with an injected translator proving first-failure/second-success stays loading then resolves, two failures expose one final error, the second attempt never starts after the shared deadline, and protected-only text creates no loading entry or request.
- [ ] Run the focused state tests and confirm each new behavior fails for the intended reason.
- [ ] Add an injectable lifecycle deadline, attempt the live call at most twice within the remaining deadline, and keep cache recovery ahead of the final error.
- [ ] Apply `containsMeaningBearingText` to request gating without changing existing edit/cache keys.
- [ ] Run the focused state tests and confirm they pass.

### Task 3: Measured glyph-only transition widget

**Files:**
- Create: `lib/features/chat/widgets/translating_message_content.dart`
- Test: `test/translating_message_content_test.dart`

**Interfaces:**
- `TranslatingMessageContent` consumes authored/final widgets, async translation state, direction, delivery state, cache/initial-final state, and reduced-motion state.
- Exposes stable keys for authored, wave, empty reshape, final landing, and settled content.
- Uses `AnimatedSize` around the real hidden final child so width and height resolve together without approximate width arithmetic.

- [ ] Add failing widget tests for subtle arrival, authored hold, 350 ms glyph wave, fast direct-final, medium clear/reshape/land, slow clear/reshape/land, unchanged result, metadata exclusion, and reduced-motion direct swap.
- [ ] Run the focused widget test and verify the first missing-widget failure.
- [ ] Implement arrival and pending phases with a `ShaderMask` applied only to the authored content.
- [ ] Run the arrival/wave tests and confirm they pass.
- [ ] Implement sequential clear, empty measured reshape, and final left-to-right land with total land time capped at 220 ms.
- [ ] Run the full focused widget test and confirm it passes.
- [ ] Refactor duplicated timers/controllers only after the behavior is green, then rerun the focused test.

### Task 4: Bubble, incoming hold, header status, and photo integration

**Files:**
- Modify: `lib/features/chat/widgets/message_learning_content.dart`
- Modify: `lib/features/chat/chat_screen.dart`
- Create: `lib/features/chat/state/translation_activity_state.dart`
- Test: `test/message_learning_content_test.dart`
- Test: `test/chat_translation_lifecycle_test.dart`

**Interfaces:**
- `MessageLearningContent` remains the final-content renderer for tappable words, corrections, alternatives, and long-press reveals.
- `_Bubble` wraps only the message/caption content in `TranslatingMessageContent`; reply preview, photo, metadata, reactions, and failure rows retain their existing ownership.
- `translationActivityProvider(chatId)` reports delayed incoming `Translating…` status to the header and clears stale entries on resolution, mode switch, edit, or delete.

- [ ] Add failing tests proving Normal outgoing never animates, Practice outgoing waits for delivery, incoming Practice hides original and captioned photo until resolution, photo-only content appears immediately, incoming failure reveals original plus Retry, and cached content skips motion.
- [ ] Add failing tests proving the header status appears only after 350 ms for held incoming work and clears when work resolves or mode changes.
- [ ] Run both focused suites and confirm the intended failures.
- [ ] Split final content construction from loading/error branches in `MessageLearningContent` so the lifecycle wrapper can own visibility and motion without duplicating text.
- [ ] Integrate the lifecycle wrapper, incoming atomic hold, and header activity state in the chat surface.
- [ ] Preserve long-press/reply/reaction targets while a wave runs and keep word/audio actions inactive until final output.
- [ ] Run both focused suites and confirm they pass.

### Task 5: Failure copy, reduced motion, concurrency, and documentation

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_de.arb`
- Modify: `lib/l10n/app_es.arb`
- Modify: `lib/l10n/app_uk.arb`
- Regenerate: `lib/l10n/generated/app_localizations*.dart`
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `tasks/tech-spec.md`
- Modify: `tasks/progress.md`
- Test: `test/chat_translation_lifecycle_test.dart`

**Interfaces:**
- Adds localized `Translating…`, `Checking…`, and `Couldn’t check · Retry` copy.
- Completed outgoing resolves are queued oldest-first per chat; waves may continue independently.
- Scroll-in-progress defers only the visible resolve transition, not translation completion.

- [ ] Add failing tests for translation-vs-correction Retry copy, oldest-first nearby completion, mode switch cancellation, deletion cancellation, and scroll deferral.
- [ ] Run the focused tests and confirm the intended failures.
- [ ] Add the localized copy and connect result mode to the correct failure/status language.
- [ ] Add the small per-chat resolve queue and scroll deferral gate; discard stale completions by message/target/mode identity.
- [ ] Record the lifecycle architecture as a resolved engineering decision and update Step 2.11 progress without marking it complete before the owner device matrix passes.
- [ ] Run formatting and localization generation.
- [ ] Run `flutter analyze` and the complete `flutter test` suite.
- [ ] Build and hot reload the connected Android phone.
- [ ] Exercise the available device cases, capture a screenshot, and leave Step 2.11 in progress for any owner-only matrix cases that were not demonstrated.

## Self-review

- Spec coverage: all acceptance-criteria categories map to Tasks 1–5; reliability fallback infrastructure itself remains out of scope as specified.
- Placeholder scan: no TBD/TODO/“similar to” steps.
- Type consistency: eligibility and branch helpers feed request gating and the transition widget; the existing `AsyncValue<MessageTranslation>` boundary remains unchanged across state and UI tasks.
