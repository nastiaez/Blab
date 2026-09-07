# Design: message lifecycle and translating state

**Status:** Approved, ready for implementation planning
**Date:** 2026-08-18
**Supersedes:** the translating-state portions of `2026-08-11-mode-display-fixes-design.md`
**Related:** Normal/Practice modes, US-015, US-016, US-042, FR-13, FR-25, FR-34, FR-35

## Purpose

Blab must make a message feel sent immediately, then make translation or correction feel like one clear transformation—not a duplicate, a jump, or an unexplained delay. The chat stays a familiar messaging surface: delivery and language help are separate states, and a failed language aid never hides the message.

This specification covers every message state in Normal and Practice modes: sent, translated, corrected, unchanged, ambiguous, failed, incoming, edited, deleted, mixed-content, photo caption, cached, and reduced-motion states.

## Principles

1. **One readable result at a time.** Never show source and generated text together in a bubble.
2. **The message is always real.** The authored text remains visible while Blab works, except when a result is so fast that it can land directly as the final message.
3. **The wave means processing.** It travels across all rendered message content, including emoji and protected content, but never across the bubble background.
4. **No visual punishment for typing mechanics.** Silent mechanical fixes do not create correction marks.
5. **Delivery is independent.** A clock or failed-send state is about delivery. A translation/checking state begins only after delivery succeeds.
6. **Never dead-end the user.** A language-help failure leaves the original usable and offers Retry. Capacity exhaustion is an internal reliability incident, never a user-facing limit.

## Content eligibility

### Protected content

Emoji, URLs, @mentions, hashtags, code, intentionally preserved names, and number-only content remain part of sentence layout but are never translated or corrected. They move with the sentence when word order changes.

- A message made only of protected content skips language processing and the wave.
- Mixed text processes as one sentence. Example: `I will see you at 8pm 😊` becomes the natural target-language sentence with `8pm` and `😊` retained in their grammatically natural positions.
- Common chat abbreviations such as `brb` and `ttyl` are treated as meaning-bearing text: translate their meaning when the target language has a natural equivalent; otherwise preserve them. They are not correction mistakes.

### Correction visibility

- **Silent:** capitalization, noun capitalization, apostrophes, commas, terminal punctuation, spacing, and a stray foreign word naturally replaced in a mixed sentence.
- **Visible to the author only:** a clear meaning, grammar, agreement, or word-order mistake. The wrong fragment is muted and struck through; its replacement lands beside it. A moved word uses the same visible correction treatment rather than pretending it stayed in place.
- **Recipient:** always sees the clean final sentence, never correction marks or coaching.
- **Uncertain correction:** preserve meaning, label it as a possible correction in the existing deep-dive treatment, and never invent missing intent.

## Shared geometry and motion

### Bubble arrival

Every newly sent bubble has a subtle arrival: about **160ms**, rising **2px** and scaling from **0.98 to 1.0**. It is quiet enough that the message—not the motion—gets attention. Timestamp and delivery ticks do not fade, pulse, or change color as part of this motion.

### Waiting wave

After the message has been delivered, wait **350ms** before showing the wave.

- The band runs left-to-right across all glyphs and inline emoji, looping until resolution.
- It is never painted on the bubble background or on timestamp/ticks.
- The wave means the whole message is being processed; it does not identify individual changed words.
- Fully protected messages skip it.

### Resolve transition

The exact final layout is measured before motion begins, using the real bubble typography, padding, and width constraints. Never calculate it from approximate width arithmetic.

1. **Clear — 0–120ms.** The currently shown text clears left-to-right. For a correction, the final strike/replacement styling is not visible yet.
2. **Reshape — 120–270ms.** With the bubble empty, width and height move together to final geometry. The newest outgoing bubble uses its timestamp/ticks corner as the visual anchor, so those details remain passive while the bubble grows upward/inward where possible.
3. **Land — 270–490ms.** Final text lands left-to-right with a small upward settle. Word stagger shortens for long messages; total land time never exceeds **220ms**. A corrected pair or linked agreement change lands together with its final styling already applied.

Reshape and land are immediate back-to-back phases. There is no pause, no cross-fade between two languages, and no visible text while the bubble changes size. The result never re-wraps or moves once it has landed.

### Result-speed branches

| Resolution time after delivery | Display behavior |
|---|---|
| Under 180ms | Do not show the authored text or wave. The bubble lands at final size and the generated words land during the subtle arrival. |
| 180–350ms | Show the authored message briefly. Skip the wave, then clear → reshape → land. |
| More than 350ms | Show the authored message, then the waiting wave, then clear → reshape → land. |

## Normal mode

- **Outgoing:** shows exactly as authored. No wave and no correction.
- **Incoming in a known language:** lands immediately as authored.
- **Incoming in an unknown language:** the header shows `Translating…`; the bubble lands only once translated into the reader’s primary known language. There is no wave.
- A language being learned does not affect Normal mode. Only Known Languages decide whether the original is readable.
- The exact original remains a separate message-action decision; it is not added to this scope.

## Practice mode

### Outgoing

1. The exact authored text appears immediately, using the arrival motion.
2. After successful delivery, apply the speed branch above.
3. On success, show the clean target-language result or the author-only correction result.
4. If no language change is required, let the wave fade out and keep the exact text in place—do not clear and re-land it.

### Incoming

1. Do not show the author’s original first.
2. After 350ms, replace the normal header status with `Translating…`.
3. When ready, land the final target-language message normally, with no wave.
4. If a caption accompanies a photo, hold the photo and caption together until the caption has resolved. A photo without a caption appears immediately.

## Grammatical-form alternatives

When a generated sentence needs an unresolved feminine/masculine form, the sentence lands with its bracketed alternatives as one linked token, for example:

```text
Ти [зробила / зробив] це?
```

Only after the sentence has landed, show the non-blocking chooser on the chat background beneath it. Selecting an option makes the message resolve locally with a quick fade; it does not restart the wave. Full form ownership, contradiction, tone, and language rules are defined in `2026-08-14-grammatical-form-preferences-design.md`.

## Failure and retry

### Language-help failure

1. Keep the wave/status through one quiet retry, for a maximum of **10 seconds** total.
2. If it still fails, preserve the authored/original text in its bubble.
3. Show a muted row on the chat background directly below the bubble:
   - Translation: `Couldn’t translate · Retry`
   - Correction: `Couldn’t check · Retry`
4. Retry removes the row, uses the same wave for a visible outgoing message, then follows clear → reshape → land. Incoming retries likewise wave across the now-visible original; if it fails again, restore the same row.
5. Do not expose provider, quota, or capacity reasons to users. Monitoring, emergency headroom, and provider fallback belong to the translation reliability work.

### Delivery failure

An offline or failed send remains the existing message-delivery state: clock while queued, failed-send treatment when delivery is rejected. It receives no language wave until delivery succeeds. Retry for delivery and Retry for language help remain distinct.

## Mode switch, cache, scroll, and concurrency

- **Switch Practice → Normal:** stop any wave immediately and render the applicable Normal result. A stale Practice completion must never overwrite it.
- **Switch Normal → Practice:** use the cached final result immediately when available; otherwise enter the correct waiting state. Existing messages do not replay their individual arrival animations.
- **Cache:** a matching cached result renders as final immediately—no request and no wave. Cache variants remain scoped to the actual target language.
- **Off-screen:** processing continues. If resolution finishes off-screen, the final state is ready on return with no replayed animation and no auto-scroll.
- **During a finger scroll:** do not delay processing; only defer the visible resolve animation until the finger lifts.
- **Several outgoing messages:** each can wave independently, but completed transformations visually resolve oldest-first so two nearby bubbles do not transform at once.
- **During the wave:** reply, reaction, copy, edit, and delete remain available. Word definitions and full-sentence audio wait for final output.

## Edit, delete, and photo behavior

- **Edit by sender:** saving restores the edited authored line, then reruns this lifecycle. Any old generated result is removed.
- **Edited message seen by recipient:** retain the prior result briefly, wave over it while the edit processes, then clear → reshape → land the new result. On failure, replace the stale result with the edited original and its error row.
- **Delete:** stop the wave immediately; no pending result may reappear. Undo restores the authored message, then reuses a completed result or resumes processing with a quick resolve. What remains in either participant’s thread and the final Undo treatment are intentionally deferred to Message interaction hierarchy.
- **Outgoing photo with caption:** the photo itself does not animate. Its caption follows the outgoing Practice lifecycle.
- **Incoming photo with caption:** photo and caption arrive atomically after caption processing. On final failure, they land together with the original caption and the error row.

## Reduced motion

- No arrival rise/scale, wave, fade, stagger, or resize animation.
- Outgoing messages show a static background status after 350ms: `Translating…` or `Checking…`.
- A final result swaps directly at final size.
- Incoming messages use the same static header status before landing.

## Acceptance criteria

- [ ] Every speed branch produces exactly one readable message state at a time.
- [ ] Slow outgoing Practice messages wave over text/emoji only; bubble background and metadata remain still.
- [ ] Longer and shorter translations reshape in one measured movement with no dragging or re-wrap.
- [ ] Normal mode never corrects outgoing text and translates only incoming languages the reader does not know.
- [ ] Incoming Practice messages never expose the original before the final target message, except after a final failure.
- [ ] Protected-only messages skip processing; mixed messages preserve protected content while translating surrounding language naturally.
- [ ] Mechanical fixes are silent; clear author mistakes show the established correction treatment; recipients stay clean.
- [ ] A language-help failure always preserves readable text and an actionable Retry after one quiet retry / 10-second maximum.
- [ ] Mode switching, cache hits, off-screen completion, message edits, deletion, photo captions, grammatical alternatives, and reduced-motion behavior follow this specification.
- [ ] Manual device pass includes English → German (longer result), German → English (shorter result), mixed text + emoji, correction, unknown-language incoming Normal message, retry, photo caption, mode switch during wave, cache reopen, and reduced motion.

## Out of scope

- The visual design and placement of the Normal/Practice control.
- The final hierarchy for word taps, sentence audio, reactions, long press, swipe to reply, View original, and delete feedback.
- Deep-dive grammar explanations and correction explanations beyond their existing popup entry points.
- Translation infrastructure, monitoring, capacity alerts, or provider fallback implementation. Those are requirements for the reliability backlog item, not user-facing UI.
