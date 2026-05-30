# Blab — Brand Foundation

> Living document. Locked stages below define what Blab is. Palette, type, and logo extend this in follow-ups but cannot contradict it. Treat this as upstream of every visual decision.
>
> Brainstormed 2026-05-25.

---

## 1 · Origin

AI bots can't replace a real person — no one on the other side with stories, who's interested in yours, who you'd want to impress. Apps like Duolingo turn language into points; people finish a tree and still can't order a coffee. Blab exists because language learning got disconnected from the only thing that ever made it stick: **a real person you want to talk to.**

## 2 · Audience truth

People say they want to learn a language. What they actually want is to **be closer to someone** — a partner, a future partner, an in-law, a friend in another country, a version of themselves that exists somewhere they haven't lived.

**Language is primary. Relationship is motivation.**

The interface teaches; the human keeps you coming back.

## 3 · Archetype

- **Primary — Explorer.** Discover by doing, not studying. Curiosity over correctness. "Dive in, figure it out."
- **Secondary — Innocent.** No grades, no shame. Optimistic. Safe to try, safe to fail.

## 4 · Brand-as-person

Late 20s to mid 30s. Has lived in multiple countries — not running from anything, just drawn to new places. Has a partner from elsewhere; takes that seriously. Works somewhere fast. Reads the brief.

Walks into a party quietly. Finds one person. Stays forty minutes. Leaves knowing something real about everyone in the room without having announced themselves once. The most memorable person there — nobody's quite sure why.

Has a lot of stories. Shares them only if asked. More interested in yours.

Tries a word in your language. Gets it wrong. Laughs. Comes back next week with it right. Doesn't make a big deal of it either way.

**Refuses to:** make anyone feel small for not knowing something · pretend they understand when they don't · stay in the safe lane of English when there's a better option.

## 5 · Beliefs and enemies

Every strong brand has a villain. Blab has two.

**Enemy 1 — The Fear in Your Head.**
The voice that says "I'll embarrass myself." The moment you switch back to English because it feels safer. The thing that stops people who want to try from actually trying.

→ **Belief:** *The only wrong thing is not opening your mouth.*

**Enemy 2 — The Grade-Giver.**
Traditional language education. Verb tables. Red pens. The teacher who interrupted your sentence to fix it. Made millions of people believe they "can't learn languages." Turned human connection into a subject to be evaluated.

→ **Belief:** *Language isn't something you study. It's something that happens between people.*

## 6 · Promise

> **Blab first. Fluency follows. You already know enough to start.**

One sentence the user can hold us to. Every team decision must survive this line.

---

## Voice

**Five adjectives:** confident · optimistic · expressive · clever · friendly.

**Humor lane:** clever and lightly sarcastic. Smart, dry, kind. Never mean, never punching down, never cringe. Like a good friend who's honest with you but makes you feel safe enough to be honest back.

### We sound like

- *"Nice. Try the next one."*
- *"Still nothing? Bold move."*
- *"You said it. Aswin's turn."*
- *"Translations on. Hide them whenever."*
- *"Oops — that word doesn't exist yet."*

### We don't sound like

- *"Great job!! 🎉🎉"* — overcooked celebration
- *"You completed this lesson."* — robotic
- *"Failure! Try again."* — shaming
- *"We're sorry for the inconvenience…"* — corporate filler
- *"Hewwo bestie 🥺"* — cringe

### Tone rules

- Short. Direct. Mistakes are never the punchline.
- Microcopy carries the wit. UI itself stays calm.
- Empty states, error states, and onboarding are where the personality lives loudest.
- Confidence is the default mood — even apologies are matter-of-fact, not grovelling.

---

## Visual register — Quiet-bold

Brand expresses confidence through **restraint**, not volume.

Resolved tension: earlier "Bold" gut call versus the quiet-at-the-party character. The person beats the gut pick when they conflict. Blab is **calm everywhere except where it has to speak up**.

**Why:** Blab's product is the conversation. The brand makes space for it; it does not compete with it. Wit lands harder when surroundings are calm. Long chat sessions are eye-friendly by default.

**Reference brands (the room we're in):** Aesop · MUBI · On Running · Granola · Are.na · Verso Books · Penguin Modern Classics.

**Working palette direction (in progress):** warm cream base + cool accent + tiny honey-yellow for tappable-word moments. Exact accent (postcard blue / sage teal / deep ink-blue) being chosen.

**What to avoid:**
- Loud-bold register (BeReal / Cash App energy) — contradicts the character
- Pastel cuteness — off-brand for Explorer
- SaaS-default purples and blues — too generic, no story
- Heavy gradients, drop shadows, glassmorphism — visual noise crowds the conversation

---

## Color palette (locked 2026-05-26)

| Token | Hex | Name | Role |
|---|---|---|---|
| `--color-primary` | `#D4694A` | Terracotta | Brand color · primary actions · outgoing bubbles · highlights |
| `--color-secondary` | `#D6E2E7` | Pale blue | Soft surfaces · incoming bubble tint · subtle accents |
| `--color-bg` | `#EFEBE2` | Warm cream | App background — Blab's distinctive world |
| `--color-dark` | `#1F3340` | Deep slate | Headers · dark mode surface · strong contrast |
| `--color-surface` | `#FFFFFF` | White | Cards · sheets · raised surfaces |
| `--color-text` | `#2C2C2C` | Near-black | Primary text |
| `--color-muted` | `#9A9490` | Warm gray | Captions · timestamps · disabled states |

**Why this palette wins:** Postcard world. Warm cream base keeps Blab out of the SaaS-blue chat-app pile. Terracotta is warm-but-grounded — friendly without burning eyes over hour-long chats. Pale blue secondary lets us cool down softer moments without dropping the warmth. Slate dark provides genuine contrast for headers and dark mode.

**Rules:**
- Cream is the default background. White is for raised surfaces only (cards, sheets, modals).
- Terracotta is reserved for brand and primary action — never decoration. If everything is terracotta, nothing is.
- Pale blue handles incoming bubbles, subtle dividers, and quiet surfaces. Never a primary button.
- Slate carries weight — headers, dark mode, strong text moments. Pairs strongest with terracotta.
- Word-tap highlight uses a soft honey tint (TBD exact token) so discovery moments feel warm, not aggressive.

## Logo (locked 2026-05-26)

**Master wordmark:** custom lowercase "blab" in terracotta. Distinctive open-counter b's, single-storey a. Used at 96–240px wide for splash, header, settings, footers, web. File: `Logo Blab.svg`.

**App icon:** lowercase "b" in cream on terracotta tile, rounded corners with one squared bottom-left (subtle bubble silhouette without being a literal speech bubble). Survives down to 24px (notification, browser tab). Pairs cleanly on cream, white, and slate backgrounds — terracotta-on-slate is the strongest pairing for splash and dark moments.

**Concept origin:** seed was "first letter of the wordmark, tiled." Adopted bubble-corner silhouette knowing the speech-bubble-cliché risk — defensible because the tail-corner is subtle (one corner cut, not a full bubble shape).

---

## Typography (locked 2026-05-26)

**Stack:** system fonts only — no custom font loaded.

```
font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', Roboto, sans-serif;
```

- **iOS:** SF Pro Text / SF Pro Display
- **Android:** Roboto
- **Non-Latin scripts** (Tamil, Devanagari, Cyrillic, etc.): system fallback (Noto Tamil, Noto Devanagari, etc.) — keeps consistency across both platforms with no extra weight or licensing.

**Why system fonts:** maximum legibility, zero loading cost, full multilingual coverage out of the box, native feel on each platform. Custom display fonts would compete with the conversation — the brand's job is to make space for the chat, not impose typography.

**Type rules:**
- **No italics anywhere** in chat surfaces — neither in translations under bubbles nor in transliteration in the word popup. Italic adds noise that competes with non-Latin scripts.
- **Weight is the differentiator,** not style: 600 for names/anchors, 500 for primary text emphasis, 400 for body, all sizes share the same family.
- Sizes follow platform defaults — 17px nav title, 15px body, 13px transliteration, 12px translation/caption, 11px timestamp.

---

## Chat screen rules (locked 2026-05-26)

### Header
- Background: cream (`--color-bg`). No dark slab. 1px muted divider at bottom.
- Layout (left to right): back arrow · avatar · name · overflow icon.
- **Back arrow:** terracotta `#D4694A`, 28px, weight 300 — reads as a brand action.
- **Avatar:** 36×36 terracotta tile with bubble-corner radius (`50% 50% 50% 10px`) — same silhouette as the app icon. Initial in cream, weight 700.
- **Name:** 17px / 600, ink, text-aligned left. Sole content of the title block — no language subtitle. (Language-pair info lives on the chats-list exchange card, not in the chat header.)
- Overflow icon: warm gray, 22px.

### Message bubbles
- **Incoming:** background `--color-secondary` (`#D6E2E7` pale blue), text near-black, border-radius `18px 18px 18px 4px` (tail bottom-left), aligned left.
- **Outgoing:** background `--color-primary` (`#D4694A` terracotta), text white, border-radius `18px 18px 4px 18px` (tail bottom-right), aligned right.
- Max-width 78% of chat area. Padding `10px 14px`. Font-size 15px, line-height 1.4.
- **All text inside bubbles uses `text-align: left`** explicitly — outgoing bubbles sit right in their wrapper but text inside reads left-aligned.

### Translation (under bubble)
- 12px, weight 400, no italic, line-height 1.3.
- On incoming bubble: warm gray (`--color-muted`).
- On outgoing bubble: light cream tint (`#FFE3D9`) for legibility on terracotta.
- Margin-top 4px from the message text.

### Word tap-state (highlight when popup is open)
The tapped word inherits the bubble's own color family — never crosses over.

| Bubble | Fill | Ring |
|---|---|---|
| Incoming (pale blue) | `#A8C1CC` (deeper blue) | `#3B5F73` (deepest blue, 2px) |
| Outgoing (terracotta) | `#B85638` (deeper terracotta) | `#8A3920` (mid-warm rust, 2px) |

Padding `1px 5px`, border-radius `5px`. No cross-bubble color contamination — keeps each side visually self-contained.

### Word popup (FR-12)
- Triggered on word tap. Floats over the tapped word — **no scrim**, rest of chat stays readable.
- Card: white background, padding `12px 14px`, border-radius `14px`, width ~200px, soft slate-tinted shadow.
- Tail arrow points at the tapped word.
- Clamped to phone bounds — never overflows the viewport edge.
- **Layout (all left-aligned, no italics):**
  - Top row: original word (18px / 600 ink) on the left · speaker icon on the right
  - Transliteration line (13px / 400 warm gray) — normal weight, no italic
  - Meaning (15px / 400 ink)
  - **No divider line** between transliteration and meaning — vertical spacing alone handles separation.
- Dismiss: tap outside, or tap another word to move the popup.

### Composer
- White pill (raised surface) with subtle shadow, margin `8px 12px 14px`, border-radius 24px.
- Placeholder text: warm gray, 14px, `text-align: left`.
- Send button: 32×32 terracotta circle, white arrow, right-aligned.

### Audio / speaker icon (single source of truth)
**Lucide-style speaker + waves**, line icon, 20×20 in the popup. Stroke 2, terracotta `#D4694A`.

```svg
<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#D4694A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/>
  <path d="M15.54 8.46a5 5 0 0 1 0 7.07"/>
  <path d="M19.07 4.93a10 10 0 0 1 0 14.14"/>
</svg>
```

**This is the only audio icon in the app.** Used wherever TTS is offered: word popup, full-message playback (FR-13), profile pronunciation samples, anywhere else. Change once, change everywhere — no emoji 🔊, no alternative glyphs.

---

## How to use this document

- **Before any visual decision** (color tweak, type pick, button shape, illustration style), check it against the brand-as-person and the visual register. If they conflict, the brand wins.
- **Before any copy** (button label, empty state, error, onboarding), check against the "we sound like / we don't sound like" lists.
- **For chat screen work,** the rules in "Chat screen rules" above are binding. Tweaks to spacing/sizing are fine; structural changes (header layout, bubble colors, tap-state behavior) need a deliberate spec edit.
- **When in doubt,** ask: would the person described in stage 4 do this?

---

## Open / to be designed

- Chats list screen (entry point, exchange card per chat)
- Profile + edit-profile flow
- Splash screen + onboarding (wordmark + slate hero treatment)
- Empty states (no chats yet, no internet, etc.) — where the voice rules from above land loudest
- Dark mode (slate-based, terracotta accent retained)

Add these to the spec as they're locked.
