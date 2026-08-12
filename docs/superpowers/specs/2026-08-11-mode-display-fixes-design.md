# Design: Mode display fixes (device-pass findings)

Status: approved, ready for planning
Follows: `2026-08-11-modes-known-languages-design.md` (this fixes gaps found in that feature's first on-device pass)

## Problem

Three issues surfaced testing the modes/known-languages feature on a real device:

1. **Practice mode shows two lanes while a message is sending.** Send an English message in a practice-mode chat targeting German: while the translation resolves, the bubble shows a loading shimmer lane *plus* the English original underneath. The redesign's rule is one lane, always, collapsed by default.
2. **Bubble height jumps between modes.** The same message renders visibly taller in practice mode than normal mode once loading finishes.
3. **"Translation unavailable / Retry" appears in normal mode on messages that never needed translating.** A message in a language the reader already knows shows an error affordance for a translation that was pointless to attempt.

## Cause

**1 — stale loading layout.** `MessageLearningContent`'s `AsyncLoading` branch still returns `_PendingTranslation`, the pre-redesign widget that stacks a shimmer subtitle above the authored text. Normal mode was updated to render a single plain line while loading; practice mode kept falling through to the old two-lane widget. It was never revisited when single-lane-default landed.

**2 — word-tap padding inflates the line box.** Practice mode renders its learning-language line through `MessageText`, which wraps every content word in its own `WidgetSpan` with `EdgeInsets.symmetric(vertical: 2)` so wrapped-line tap targets stay comfortable. Normal mode renders a plain `Text` with no per-word wrapping. Across a full sentence those paddings compound into a taller line box, so the same content occupies more height in practice mode.

**3 — normal mode still translates everything, then can't explain the failure.** Normal mode fires a translation request for *every* message, because the source language isn't known client-side until the server responds. For a message in a language the reader already knows, that request is pure waste. When it fails, the reader gets an error and a Retry button on text they can read perfectly.

This is also a gap against the feature's own premise. The spec's Problem section is "no way to just talk without the AI rewriting every message" — but normal mode currently still routes every message through the translator, it just discards the result when the source language turns out to be known. The AI is still reading everything; the user simply doesn't see it.

## Fixes

### 1. Single lane while loading, both modes

Practice mode's loading state renders the authored text as one plain line — same as normal mode already does — with no shimmer subtitle and no second lane. Once the translation resolves, the learning-language line replaces it in place.

Keeping the existing 350ms delay-before-shimmer behavior is pointless once there's no shimmer to delay, so `_PendingTranslation` and its timer are removed entirely rather than left unused.

**Trade-off accepted:** no visible in-progress signal on a slow translation. The message is readable throughout (it's the text the author typed), and the swap to the learning language is the completion signal. This matches the redesign's "collapsed is always one lane" rule literally, which the current shimmer treatment violates.

### 2. Height parity between modes

Both modes render their single line through the same text path, so identical content occupies identical height regardless of mode. The per-word tap padding that inflates practice mode's line box moves off the layout: tap targets stay comfortable via hit-test expansion rather than by growing each word's painted box.

Verified by a widget test asserting the rendered height of the same message is equal in both modes.

### 3. Normal mode stops translating what the reader can already read

**Server-side.** `request_message_translation` already receives the caller's mode and, since this feature, their `known_languages`. When the caller is in normal mode and the message's source language is already known to be in their known-languages list, the function returns "no aid needed" without calling the LLM at all.

Source language comes from the `message_translations` cache when any prior resolution recorded it — the row stores `source_lang` independent of who requested it. First sighting of a message with no cache row still needs one detection round-trip; every subsequent reader and every re-render is free.

This is the fix that makes normal mode honest: for a chat where both people write a language the reader knows, after first sighting, no message ever reaches the translator.

**Client-side.** Error and retry chrome appears only when the app positively knows the message needs translating — i.e. a resolution recorded a source language that isn't in the reader's known list. When the source language is known-to-the-reader, or not yet determined, a failed request renders the authored text silently and leaves the existing background auto-retry to recover.

This is deliberately narrower than the current behavior, which shows error chrome on *any* normal-mode failure. It resolves the tension that made the previous two attempts wrong in opposite directions: suppressing all errors hid genuine failures on unreadable messages; showing all errors put retry buttons on messages nobody needed translated.

## Resolved: failure before source language is known

**Decision: stay silent, rely on background auto-retry.** When translation fails for a message whose source language has never been resolved, the reader sees the authored text with no error and no retry button. The existing background retry keeps working and the message resolves itself the moment a request succeeds.

Accepted risk: if retries never succeed — a persistently unsupported pair, a sustained backend outage — the reader is left looking at text they can't read, with no explanation. This is narrow (it needs both a never-before-resolved message *and* persistent failure) and self-heals on any successful retry. Chosen over surfacing chrome because the far more common case is a message the reader can already read, where an error affordance is pure noise — which is the bug that prompted this spec.

Revisit if real usage shows persistent failures stranding readers.

## Out of scope

- No change to practice mode's correction rendering, tap targets, or the expand/collapse icon.
- No change to `translation_cutoff_at` (the learning-language-change freeze).
- No new user-facing strings beyond what the fixes above require.
