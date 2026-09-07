# Blab product design backlog

This is the working list for product and UX decisions. It is not the developer build plan. An item moves to the build plan only after its behavior is agreed and its spec is ready.

## Current build sequence

1. **Outgoing-bubble alignment** — in progress
2. **Gender-choice visual refinement** — then test the full selection flow
3. **Practice-mode device feedback** — resolve each item in order
4. **Message lifecycle animation** — build from the approved specification
5. **Message lifecycle device test**

## Chat screen — agreed order

### 1. Message lifecycle and animation — in progress

Define what happens from Send through processing and resolution for translated, corrected, unchanged, ambiguous, failed, incoming, and Normal-mode messages.

Already agreed:

- Grammatical-form choices and memory: `docs/superpowers/specs/2026-08-14-grammatical-form-preferences-design.md`
- Translating-state starting point: `docs/superpowers/specs/2026-08-12-translating-state-animation-design.md`

### 2. Message interaction hierarchy

Decide the clearest hierarchy for word taps, message taps, long press, swipe to reply, reactions, full-sentence audio, translation expansion, and correction explanations.

Follow-up to include:

- Restore **View original** from long press without overcrowding the existing action row.
- Redesign message deletion: decide what remains in the thread for each person, what the deleted-message copy says, and where/how long Undo is available.

### 3. Learning deep dives

Design what learners can explore beyond the bubble: word meaning, sentence structure, grammar explanations, alternative phrasing, and why a correction was made.

Account for beginners who need phrase structure and advanced learners who need nuance rather than basic definitions.

### 4. Normal/Practice mode control and transition

Improve the toggle's position, hierarchy, and appearance. Explore a calm Normal mode and a more distinctive Practice-mode atmosphere without making the chat unfamiliar.

### 5. First-use guidance inside chat

Design lightweight, contextual teaching for the first chat and first learning interactions. Candidates include empty-chat copy such as “Write in any language. Blab turns it into Tamil.” and a first-use hint such as “Tap any word to explore it.”

### 6. Translation speed and perceived performance

Separate actual translation latency from perceived waiting time. Review request timing, caching, retries, vocabulary growth, and which feedback makes the app feel responsive without adding noise.

Treat exhausted translation capacity as an internal reliability incident, not a user-facing limit: alert before exhaustion, keep emergency headroom, and define automatic recovery or provider fallback so users retain an actionable Retry path.

### 7. Chat visual polish and delight

Review icons, bubble details, background, spacing, motion, audio affordances, accessibility, and the small moments that currently make the app feel stiff.

### 8. Ambiguous names and terms — low priority

Design a transparent, non-blocking interpretation for likely misspelled places, people, brands, slang, and other meaning-bearing terms. The translated sentence can use a strong candidate, but Blab must never silently present a guess as fact. Explore a quiet row on the chat background, for example `Possible match: Tempelhof`, which reveals what was typed and why Blab made the match. Preserve the original when confidence is insufficient.

## After the chat screen

1. Onboarding: explain that people can write in any language, how Normal and Practice modes differ, and what each person can expect.
2. Invite-a-friend flow: rewrite the language choice so it cannot be mistaken for changing the whole app language, then redesign the link screen.
3. Wider UI polish: apply the strongest chat-screen visual decisions across the rest of the app.
