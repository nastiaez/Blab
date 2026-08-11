# Design: Normal/Practice modes + known languages

Status: approved, ready for planning
Supersedes/updates: FR-13, FR-19, FR-20, FR-23, US-014, US-015 (translation/correction display rules), interacts with US-022 (learning language selection, unchanged)

## Problem

Today, every chat runs one always-on pipeline: the viewer's learning language on top, their interface language below, corrections applied whenever the author writes in their own learning language. This breaks down for a real case: Nastia and her mum both speak Ukrainian natively and text in Ukrainian, but the chat is configured as a language-exchange chat (mum learning English, Nastia's interface language is English). Mum's Ukrainian gets run through the pipeline as if it were her practicing English — corrected and translated into English, a language neither of them was actually using. Ukrainian, their real shared language, never appears. There's no way to just talk without the AI rewriting every message, and no way to tell what was said versus what the app generated.

## Model

### Modes

Two modes replace the always-on pipeline: **normal** and **practice**. Set per person, per chat (not shared/synced with the chat partner) via a toggle always visible at the top of the chat. New chats default to practice.

- **Normal:** no corrections, ever — messages show exactly as typed, mistakes included.
- **Practice:** the chat's learning language (set via the existing US-022 picker, unchanged) is corrected/translated into on the top line, same as the current pipeline.

### Known languages

Each person has one global list of known languages, managed in Profile — not per chat. Add or remove languages freely; one is marked **primary**. Known languages are read without any help — no translation, no correction, regardless of mode.

Primary is only a tiebreaker: it's the translation target when a message needs translating (i.e., it's in a language that isn't on the known list at all). It does **not** rank known languages against each other — if a message is in *any* known language, it's shown as-is, full stop, primary or not.

Interface language is unchanged and unrelated to any of this — it only controls the language of buttons, menus, and system copy. It is never a translation target.

Onboarding flow for seeding the known-languages list is deferred to a separate decision. Until that ships, fall back to seeding the list with the account's interface language so the list is never empty.

## Display logic

Applied per message, per reader, in this order:

1. **Practice mode and the message is in the chat's learning language** → show the learning-language line: corrected if the author wrote it in that language, translated into it if they wrote it in something else. This fires even if that language also happens to be on the reader's known list — deliberately practicing a language you already know (e.g. grammar polish for a heritage speaker) still gets corrected.
2. **Otherwise, message language is on the reader's known list** → show as authored. No translation, no correction.
3. **Otherwise (not known, and not rule 1)** → translate. Normal mode targets the reader's primary known language. Practice mode also targets the learning language, matching today's behavior of translating anything into the language being practiced.

Corrections (the crossed-word treatment) only ever render for the person who made the mistake, viewing their own message. Everyone else always sees the clean result — unchanged from today's behavior.

Historical messages are not migrated or re-cached when known languages change. Rendering always reflects the reader's *current* settings, exactly as it does today — add Polish to your known list and every past Polish message switches to original-only immediately, no backfill needed.

This is different from changing your **learning language** for a chat, which already has separate, unchanged behavior: it starts a new translation "era" (`translation_cutoff_at`). Messages sent before the change freeze to plain original — no dual-lane, and they don't get retroactively translated into either the old or the new learning language. Only messages sent after the change get rule 1's treatment for the newly selected language. Known-language changes are live and retroactive; learning-language changes are not — this spec doesn't touch that distinction, just documenting it since it affects what a reader sees after either kind of change.

A language can be both known and a chat's learning language at once — no exclusivity enforced. Rule 1 above means the learning-language treatment wins for that specific chat regardless of known status, so nothing breaks: known controls every *other* language, learning controls this one, for this chat. Real case for allowing it: someone who already speaks a language casually but wants grammar polish in one particular chat.

## Bubble layout

Collapsed by default: always exactly one lane (whichever line the rules above select), full stop — no per-language or per-user adaptive default. Below it, a translate icon — only present for rule 1's case (practice mode, learning-language line), since that's the only case with a second lane to offer. Rule 2 (known language) and rule 3 (translated-because-unknown) each render a single lane with nothing to expand. Tap the message or the icon to expand rule 1's second lane: divider, known-language translation below. Once expanded, the translate icon is replaced by a "play full sentence" audio icon, with a chevron to collapse back. Scrolling a message out of view re-collapses it.

Tapping a word (not the bubble padding) opens the existing word-lookup popup; dotted underlines only appear once a message is expanded.

**Seeing the true original:** switching the whole chat to normal mode is the mechanism — no separate "view original" link on the bubble. This only surfaces the original for languages already on your known list (rule 2 above); for a message in a language you don't know at all, there's nothing on it to unlock — add that language in Profile if you want to see it un-translated, same as any other known language.

Switching modes resets the chat's open UI state: every expanded message re-collapses, any open word popup or reaction picker closes. Animated transition, not a hard cut.

## Corrections detail

- Mechanical mistakes (capitalization, apostrophes, commas, a stray foreign word swapped back into the learning language) fix silently, no marks.
- Meaning-level mistakes: the corrected word sits in the learning-language line. Tapping it opens the existing word popup with one added line — why it was corrected. No separate block under the bubble. (The explanation text is already generated and stored by the translation service today; it's just never rendered — this wires it into the popup for the first time.)
- Two visual treatments for corrected words: brand-color for a word you were missing entirely (insertion), muted strikethrough for a word you got wrong (replacement). Today's implementation only has the strikethrough treatment — the insertion color is new.
- Mixed-language input is never flagged as an error — type mostly in the learning language, drop in one word from elsewhere, and that word renders as a normal correction gap (highlighted as "missing"), not a special warning state.

## Privacy

Learning language is never visible to the chat partner — not in the empty state, not in their view of your profile, not on the bubble. (Known languages are not private in the same way — they're a fact about you, not a vulnerability, so no equivalent restriction applies there.)

## Explicitly dropped / out of scope

- **Premium / paywall gating.** The model supports unlimited known and learning languages for everyone; no gating logic, no billing, in this build. If monetization returns later, it reopens the PRD's "no in-app payments" non-goal as its own decision.
- **Per-chat known-language overrides.** Considered, dropped — knowing a language doesn't depend on who you're talking to, a global list covers every case discussed.
- **Adaptive default-expand state** (e.g. starting new/unfamiliar languages with the translation lane pre-opened) and the auto-hide-with-toast idea that came with it. Every message defaults to one lane, no exceptions, no proficiency-based behavior.
- **Auto-restoring hidden translations.** N/A now that the auto-hide idea itself is dropped — moot.
- **A visible "unknown-source" tag or icon** on translations from a language the reader doesn't know at all. No marking — the translation just appears.
- **The "AI" label.** Removed. Once translation/correction is the default behavior of a lane rather than an exception, a badge on it stops being informative. Trust signals stay limited to what's verifiable (switch to normal mode to see the real text) rather than a label.

## Open follow-ups (not blocking this spec)

- Onboarding flow for seeding known languages at signup.
- Whether/how to surface "you can add this language in Profile to see the original" in the moment someone hits an unknown-language message, versus leaving it to Profile discovery.
