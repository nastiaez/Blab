# Design: incoming message lifecycle parity

**Status:** Approved
**Date:** 2026-09-11
**Supersedes:** the incoming pending-state motion in `2026-08-12-translating-state-animation-design.md` and the static-skeleton behavior in `2026-08-28-chat-history-readiness-storage-design.md`
**Related:** US-043, US-044, FR-36, FR-38

## Purpose

Incoming and outgoing translation must feel like two directions of the same Blab interaction. Incoming Practice messages still protect the sender's authored text while translation is pending, but they use the same timing, wave, measured reshape, and text-landing language as outgoing Practice messages.

## Approved behavior

### Shared motion grammar

- Every newly visible bubble uses the existing quiet 160 ms arrival: rise 2 px and scale from 0.98 to 1.
- Under 180 ms, the final translated message lands directly with no pending placeholder.
- From 180–350 ms, incoming Practice shows its neutral two-line placeholder briefly, then clears, reshapes while empty, and lands the translated text.
- After 350 ms, a light band moves across the two placeholder lines. When translation resolves, the lines clear left-to-right, the empty bubble reshapes over 150 ms, and translated text lands left-to-right in at most 220 ms.
- Incoming and outgoing bubbles use the same phase timing and easing. Their only content difference while pending is intentional: outgoing shows authored text; incoming shows neutral placeholder lines.
- The bubble background, outline, timestamp, read state, reactions, and reply preview never shimmer.

### Privacy and content

- Incoming Practice never reveals the sender's authored text before a successful result, except after final failure.
- Incoming Normal follows the existing readability rule: known-language authored text appears immediately; an unknown-language message uses the pending lifecycle.
- Final failure replaces only the affected placeholder with authored text plus the existing Retry action.
- Cached and off-screen-completed results paint final immediately and do not replay motion.

### Translation status

- A single pending incoming message has no separate `Translating…` row; the bubble motion is sufficient feedback.
- Two or more pending incoming messages retain one muted `Translating N messages…` group row.
- Pending messages resolve oldest-first. Each bubble owns its phase, so simultaneous arrivals do not share or reset animation state.

### Reduced motion

- Arrival, wave, clear, resize, and landing motion are disabled.
- Pending incoming content is represented by the same two static neutral lines.
- Resolution swaps directly to the final measured message.
- The group count remains visible only for two or more pending messages.

## Alternatives rejected

1. Showing incoming authored text under the same wave was rejected because Practice must not expose unprocessed source text.
2. Keeping the existing static placeholder and status row was rejected because it does not share Blab's established message-lifecycle language.
3. Hiding the whole incoming bubble until completion was rejected because slow translation would look like delayed delivery rather than visible processing.

## Verification

- Automated widget coverage proves fast, medium, slow, failure, cached, reduced-motion, and independent simultaneous-message phases.
- Device review records outgoing and incoming slow translation, two simultaneous incoming messages, and reduced motion.
- Video evidence shows the complete pending-to-final lifecycle; still frames capture the slow pending and final states.

## Acceptance criteria

- [ ] A slow incoming message visibly waves across only the two placeholder lines, then clears, reshapes empty, and lands translated text.
- [ ] Incoming and outgoing use matching timing and easing without exposing incoming authored text.
- [ ] One pending incoming message has no standalone status row; multiple pending messages show one accurate group count.
- [ ] Simultaneous messages resolve oldest-first without phase leakage or animation reset.
- [ ] Reduced motion uses static placeholder lines and a direct final swap.
- [ ] Cached/off-screen results render final without replay.
- [ ] Device video and screenshots demonstrate the approved lifecycle.
