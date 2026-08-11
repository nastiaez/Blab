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

Mode decides everything — known languages only matter in normal mode:

1. **Practice mode** → every message shows the learning-language line, full stop. Corrected if the author wrote it in that language, translated into it if they wrote it in anything else — regardless of whether the source language happens to be on the reader's known list. Known status has no effect in practice mode at all; the whole point is immersion in the language being practiced. To see a message as the author actually typed it, switch the chat to normal mode.
2. **Normal mode, message language is on the reader's known list** → show as authored. No translation, no correction.
3. **Normal mode, message language is not known** → translate into the reader's primary known language.

When practice mode's second lane is expanded (see Bubble layout below), it always translates into the reader's primary known language too — one consistent target, not chosen per-message based on what the author wrote.

Corrections (the crossed-word treatment) only ever render for the person who made the mistake, viewing their own message. Everyone else always sees the clean result — unchanged from today's behavior.

A language can be both known and a chat's learning language at once — no exclusivity enforced, and no special-casing needed: rule 1 already applies uniformly to every message in practice mode regardless of known status, so nothing to reconcile. Real case for allowing the overlap: someone who already speaks a language casually but wants grammar polish in one particular chat.

Historical messages are not migrated or re-cached when known languages change. Rendering always reflects the reader's *current* settings, exactly as it does today — add Polish to your known list and every past Polish message (in a normal-mode view) switches to original-only immediately, no backfill needed.

This is different from changing your **learning language** for a chat, which already has separate, unchanged behavior: it starts a new translation "era" (`translation_cutoff_at`). Messages sent before the change freeze to plain original — no dual-lane, and they don't get retroactively translated into either the old or the new learning language. Only messages sent after the change get rule 1's treatment for the newly selected language. Known-language changes are live and retroactive; learning-language changes are not — this spec doesn't touch that distinction, just documenting it since it affects what a reader sees after either kind of change.

## Bubble layout

Collapsed by default: always exactly one lane (whichever line the rules above select), full stop — no per-language or per-user adaptive default. A translate icon sits beside the bubble, toward the center of the screen — not below the text — and only appears in practice mode (rule 1), since that's the only case with a second lane to offer. Normal mode (rules 2 and 3) always renders a single lane with no icon. Tapping the icon (not the message itself — that's already spoken for by word taps and long-press) expands the second lane: divider, translation into the reader's primary known language below. Once expanded, the icon swaps to a "play full sentence" audio icon, with a chevron to collapse back. Scrolling a message out of view re-collapses it.

No dotted underlines on tappable words — words are tappable at all times regardless of collapsed/expanded state, so an underline that only shows up on expand would misrepresent when tapping actually works.

**Seeing the true original:** switching the whole chat to normal mode is the mechanism — no separate "view original" link on the bubble. This only surfaces the original for languages already on your known list (rule 2 above); for a message in a language you don't know at all, there's nothing on it to unlock even in normal mode — add that language in Profile if you want to see it un-translated, same as any other known language.

Switching modes resets the chat's open UI state: every expanded message re-collapses, any open word popup or reaction picker closes. Animated transition, not a hard cut.

## Corrections detail

- Mechanical mistakes (capitalization, apostrophes, commas, a stray foreign word swapped back into the learning language) fix silently, no marks.
- Meaning-level mistakes keep today's single visual treatment — muted strikethrough on the wrong part, corrected text right after it. No second color for insertions; not worth the extra visual complexity.
- The struck-through (wrong) text and the corrected text next to it are two separate tap targets, each opening a popup, reusing the existing word-popup card:
  - Tap the **corrected** text → the normal word-definition popup (word, romanization, translation, audio), same as any other tappable word.
  - Tap the **struck-through** text → a similar-looking popup, but showing the explanation of what was wrong instead of a definition. (The explanation text is already generated and stored by the translation service today; it's just never rendered — this wires it into the popup for the first time.) Kept as a separate popup rather than merging both into one, since a combined card gets cramped on short words.
  - Both spans need a reliably tappable hit area even when the words themselves are short — the two targets must stay independently tappable, not just visually distinct.
- No separate block under the bubble for corrections — this replaces that.
- Mixed-language input is never flagged as an error — type mostly in the learning language, drop in one word from elsewhere, and that word renders as a normal correction gap, not a special warning state.

## Privacy

Dropped. Considered making learning language invisible to the chat partner, but the exchange-card setup flow ("she teaches you Ukrainian ⇄ you teach her Tamil") and the partner profile sheet already reveal it to both sides by design — that's how a chat gets set up. Reworking that is a separate, larger decision, not part of this feature. Known languages were never private to begin with — they're a fact about you, not a vulnerability.

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
