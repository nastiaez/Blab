# Remove Correction Explanations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the correction-explanation popup for both outgoing and incoming inline corrections while preserving correction marks and standard corrected-word help.

**Architecture:** Keep the existing correction and prepared-package data contracts unchanged. Remove only the struck-through-text interaction and its now-unused popup surface; corrected and unchanged words continue through the existing word-help path.

**Tech Stack:** Flutter/Dart, Riverpod, Flutter widget tests

---

### Task 1: Lock the no-explanation interaction contract

**Files:**
- Modify: `test/inline_correction_text_test.dart`
- Modify: `test/message_learning_content_test.dart`

- [ ] Change the struck-through-text widget test to tap a mistake carrying a non-empty explanation and assert that no explanation text or explanation card appears.
- [ ] Change the matching-language recipient test to assert correction marks remain, tapping the struck word does nothing, and tapping the bold replacement still opens standard word help.
- [ ] Run `flutter test test/inline_correction_text_test.dart test/message_learning_content_test.dart` and confirm failure because the current UI still opens the explanation popup.

### Task 2: Remove the explanation surface

**Files:**
- Modify: `lib/features/chat/widgets/inline_correction_text.dart`
- Modify: `lib/features/chat/widgets/message_learning_content.dart`
- Modify: `lib/features/chat/widgets/word_popup.dart`
- Modify: `test/inline_correction_text_test.dart`
- Modify: `test/word_popup_test.dart`

- [ ] Remove `explanation` from `InlineCorrectionText` and its call site.
- [ ] Render struck-through segments as plain non-tappable spans.
- [ ] Preserve independent tap targets for corrected and unchanged words so word help and audio remain unchanged.
- [ ] Delete the now-unused `showExplanationPopup`, explanation overlay/card classes, and their dedicated widget test.
- [ ] Run the two focused widget test files and `test/word_popup_test.dart`; expect all tests to pass.

### Task 3: Verify and record the cleanup

**Files:**
- Modify: `tasks/progress.md`

- [ ] Run `dart format --output=none --set-exit-if-changed lib test`.
- [ ] Run `flutter analyze`.
- [ ] Run `flutter test`.
- [ ] Run `git diff --check`.
- [ ] On Chrome and Android, confirm correction marks remain, struck-through text does nothing, and corrected-word help still opens.
- [ ] Record the observed verification and commit the cleanup.
