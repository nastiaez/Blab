# Design: the translating state (the wave)

Status: approved, ready for planning
Supersedes: fix 1 of `2026-08-11-mode-display-fixes-design.md` (see § Relationship to the display-fixes spec)
Prototype: `docs/superpowers/prototypes/translating-state.html`

## Problem

In practice mode you type in one language and Blab shows you another. Between hitting send and the translation resolving there is a gap of roughly two to six seconds, and Blab has nothing to show but the words you typed.

The gap is currently unfilled. Before this spec, practice mode stacked a shimmer subtitle above the original — two lanes, contradicting the single-lane rule. The first fix removed the shimmer and left a plain, motionless line, which reads as nothing happening at all. Response-time research is unambiguous that a wait in the one-to-ten-second band needs an indicator: under one second an indicator is worse than none, over ten seconds it needs real progress, and in between the user must be able to see that the system is working.

Three constraints make this harder than a normal loading state:

- **Your own words must stay on screen.** Chat is optimistic — you see what you sent, immediately. A spinner in place of your message, or a bubble that stays empty until the server answers, is the one thing a messaging app never does.
- **One lane.** The modes/known-languages design fixes a single collapsed line. Anything stacked above or below the message breaks that rule.
- **The bubble changes shape.** The two languages rarely occupy the same space. German usually needs an extra line; sometimes it needs less. So the bubble has to resize as part of the transition, and a resizing bubble drags whatever is inside it.

## What this covers

Only messages **you** send, in **practice mode**, where the message must be rendered in a language other than the one you typed.

Messages from the other person do not animate. See § Incoming messages.

## The wave

Two states, one transition between them.

### Waiting

Your message appears the instant you send it, in the language you typed, as a single line — exactly as it will look if no translation is ever needed. After a **350ms hold**, a band of light begins travelling across the glyphs of that line, left to right, on a loop.

The hold exists because most sends resolve fast, and an animation that starts and stops within a few frames reads as a rendering glitch. A translation that beats the hold simply appears; only a wait long enough to notice gets an animation.

### Transition

Three phases, strictly sequential. No two phases ever overlap.

| Phase | Timing | What happens |
|---|---|---|
| **Clear** | 0 → 160ms | The band stops. Your words fade out one at a time, left to right — 10ms apart, 110ms each. No movement, only opacity. |
| **Reshape** | 160 → 360ms | The bubble travels to the exact size the translation needs. Width and height together, as a single motion. The bubble is empty throughout. |
| **Land** | 360 → ~600ms | The translated words fade in one at a time, left to right — 18ms apart, 140ms each, each rising 3px into place as it arrives. |

Total is roughly 600ms, varying with word count.

Direction carries the meaning: the band travels left to right, the words leave left to right, and the translation arrives left to right. The transition finishes the motion the waiting state started.

### Why strictly sequential

Every earlier arrangement failed for the same reason — two things changing at once.

- **Both languages visible together** smears them. Two texts at partial opacity in the same spot double-strike each other, worst at the opening words, where both languages start at exactly the same point and every glyph collides.
- **Text visible while the bubble resizes** drags. A bubble growing taller moves its own contents regardless of which corner the text is anchored to; there is no anchor that escapes a change in height.

Only the departing text moves in opacity; only the arriving text moves in position. This follows the established fade-through convention, where the outgoing element simply leaves and only the incoming one is given motion.

## Geometry rules

These are the rules that make the resize smooth. Each one was a visible bug in the prototype before it was fixed.

**Measure before moving.** The translated line's final width and height are measured *before* any animation begins, by rendering it hidden inside a real copy of the bubble — same font, same padding, same max-width constraint. The bubble then travels straight to that size. Computing the available width arithmetically is what went wrong repeatedly: the calculation missed the bubble's own horizontal padding and reported a line 28px narrower, and therefore a line taller, than the one that actually renders. Measuring a real copy removes the arithmetic entirely.

**One move, not two.** Width and height animate together over the same duration with the same easing. Animating height and letting width follow produces the tall-then-wide-then-short stutter.

**Round text widths up, never down.** A line that wants 147.09px, frozen at a rounded-down 147px, wraps its last word onto a second line and doubles the bubble's height before anything else has happened. One pixel. Always `ceil`, and offset that fraction back out so the frozen line does not twitch sideways as it is pinned.

**Freeze each line at its own width.** While the transition runs, neither line may re-wrap. The departing line keeps the width it already had; the arriving line is placed at its measured final width from the start.

**The arriving text never moves after it lands.** Because the bubble finished reshaping before the first word appeared, the position each word lands in is its final position.

## Failure

If the translation fails, the band stops and your words simply stay. No error, no retry button. Blab keeps retrying in the background and the line becomes the translation whenever a retry succeeds.

This matches the failure decision already taken in the display-fixes spec: silence, plus background retry, in preference to error chrome on a message the reader can very likely read anyway.

## Reduced motion

With reduced motion requested, there is no band and no wave. Your message shows plainly while it resolves, then the translated line replaces it in one step, at its final size. The state changes; nothing animates.

## Incoming messages

A message from the other person appears only once its translation is ready. There is no gap to fill, so there is no waiting state and no animation — it lands, already in your learning language, like any other message.

The cost is that their message is held back for as long as the translation takes. That is the right trade: the reader has no relationship to the words they didn't write, so watching those words be replaced is motion without meaning, and a thread can deliver several messages at once, where several simultaneous waves would be chaos.

**If the translation fails, the message lands in its original language rather than never arriving.** Delivery is never blocked on translation succeeding — only delayed by it.

## Relationship to the display-fixes spec

`2026-08-11-mode-display-fixes-design.md` fix 1 specified that practice mode render a plain, motionless line while a translation resolves, and accepted "no visible in-progress signal on a slow translation" as a trade-off. That trade-off is now rejected: the device pass confirmed a motionless line reads as a broken send.

This spec replaces that behaviour with the band and the wave. Everything else in the display-fixes spec stands — fix 2 (height parity between modes) and fix 3 (normal mode not translating what the reader already reads) are unaffected, as is the shared decision to stay silent on failure.

The single-lane rule is not weakened. At every moment of the waiting state and the transition there is exactly one line in the bubble.

## Out of scope

- Normal mode. Nothing there animates; a message either shows as authored or resolves silently.
- Corrections. When a message comes back corrected rather than translated, the corrected line arrives through the same wave, but the correction's own strike-through and tap targets are unchanged.
- The expand/collapse second lane, and the icon beside the bubble.
- What Blab does with a message that has nothing to translate — laughter, emoji, a bare time, a name, a keyboard mash. That is a translation-behaviour question, not an animation one, and needs its own decision.
