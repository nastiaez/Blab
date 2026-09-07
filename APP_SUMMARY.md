# Blab — app and feature summary

Last updated: 22 August 2026

## What Blab is

Blab is a one-to-one language-exchange chat app. Two real people teach each other through everyday conversation. It is not a course, tutor marketplace, or AI companion: the chat stays between people, while Blab supplies translation, correction, pronunciation, and word-level learning help.

The first public release is Android-first and supports 11 learning languages: Dutch, English, French, German, Hindi, Italian, Portuguese, Spanish, Tamil, Turkish, and Ukrainian. The interface is available in English, Ukrainian, German, and Spanish.

## Main journey

1. Create an account with email or Google, choose the interface language, and manage profile, email, password, privacy, or account deletion.
2. Pick a language to learn and share a private invite link. One person can claim it within 48 hours.
3. The recipient opens the invite, signs up or logs in, chooses the other side of the exchange, and joins the same one-to-one chat.
4. Both people send text or photos, reply, edit, delete, react, copy, and see typing/read states when both allow them.
5. Each chat can use Normal or Practice mode, with its own learning language and conversation tone.
6. Blab translates, corrects, explains words, provides romanization, and reads supported text aloud without hiding the exact authored message.
7. Before release, the full journey must pass on the Play-signed Android build, including invite links, Google sign-in, offline recovery, report/block, notifications, and store/legal requirements.

## Feature map

### Account and profile

- Email sign-up and login, Google sign-in, password reset, change email, and change password.
- Interface-language choice before and after sign-in.
- Display-name editing, known-language preferences, privacy controls, logout, and account deletion.
- Apple sign-in is reserved for the later iOS release.

### Invites and connections

- Searchable 11-language picker and a native share journey.
- Single-claim invite links with a 48-hour lifetime.
- Invite states for valid, used, expired, owner, and recipient views.
- One shared chat per pair, with invite context carried through account creation.

### Messaging

- Realtime one-to-one text chat with durable delivery, offline queueing, retry, and duplicate-send protection.
- Replies, editing, delete with Undo, reactions, read receipts, and typing indicators.
- Photo gallery, camera capture, captions, upload retry, and sharing into Blab.
- Push/foreground notification behavior and deep links back to the correct chat.

### Language learning

- **Normal mode:** authored messages remain familiar. Incoming text is translated only when the reader does not know its language.
- **Practice mode:** messages resolve into the learning language, with corrections visible only to the author and a clean result for the recipient.
- Tappable words open pronunciation, romanization, and an interface-language meaning.
- Exact original text remains available from message actions.
- Translation results are cached per message and language; errors keep the original readable and offer Retry.
- Known Languages prevents unnecessary translation, while Translation preferences stores grammatical form and per-chat tone.

### Safety, privacy, and release posture

- Report and block flows, privacy toggles, account deletion, legal pages, and scrubbed crash reporting.
- Message content is currently protected by authenticated access rules but is not end-to-end encrypted in the first release. End-to-end encryption is planned after launch and the privacy copy must say this plainly.
- Android is the launch platform. iOS, Apple sign-in, and iOS Universal Links follow later.

## Recent specification: message-bubble lifecycle and animation

The new rule is simple: a bubble must feel sent immediately, then transform once. The authored and generated versions are never readable at the same time.

### Arrival and waiting

- A new sent bubble arrives in about **160 ms**, rising 2 px and scaling from 0.98 to full size.
- Language processing starts only after delivery succeeds.
- If processing lasts beyond **350 ms**, a band of light travels left-to-right across the rendered letters and emoji. The bubble background, timestamp, and delivery ticks stay still.
- Emoji, links, mentions, hashtags, code, names, and numbers remain protected. A protected-only message skips the wave entirely.

### Three speed branches

| Result time after delivery | What the person sees |
|---|---|
| Under 180 ms | The final result lands directly during the bubble arrival. |
| 180–350 ms | The authored message appears briefly, then resolves without a wave. |
| Over 350 ms | The authored message appears, the glyph-only wave begins, then the result resolves. |

### Resolve motion

1. **Clear, 0–120 ms:** current words clear left-to-right.
2. **Reshape, 120–270 ms:** the empty bubble changes width and height together to its measured final size.
3. **Land, 270–490 ms:** final words land left-to-right with a small upward settle.

The final bubble is measured with the real text styles and padding before motion starts. It moves to that size once, stays empty during reshaping, and never re-wraps after the words land.

### Mode and failure rules

- Normal-mode outgoing text is not corrected. Incoming text in an unknown language is held until its translation can land cleanly.
- Practice-mode outgoing text appears immediately and follows the speed branches above. Incoming Practice messages wait off-screen until the final learning-language version is ready.
- One quiet retry can continue for up to 10 seconds. Final failure preserves the original and shows `Couldn’t translate · Retry` or `Couldn’t check · Retry`.
- Reduced Motion removes arrival, wave, fade, stagger, and resize animation; the final bubble swaps in one step.
- Edits, deletion, cached results, mode switches, off-screen completion, simultaneous messages, photo captions, and grammatical alternatives all have explicit lifecycle rules.

Implementation is still in progress and needs the full real-device matrix before this milestone can be confirmed complete.

## Recent build: Ukrainian past-tense grammatical forms

Ukrainian past-tense verbs, adjectives, and participles often need a feminine or masculine form. When Blab cannot know which one is correct, it now keeps both natural forms inside the translated sentence instead of guessing or forcing an unnatural neutral rewrite.

Example:

> Ти [зробила / зробив] це?  
> Did you do it?

An inline, non-blocking question appears under the message: **Which form fits Maya?** or **Which form fits you?** The buttons show the real Ukrainian words with localized secondary labels, feminine and masculine. The person can ignore the choice and continue chatting.

Tapping the bracketed words opens the normal learning card:

- `зробила / зробив`
- `zrobyla / zrobyv`
- `did (feminine) / did (masculine)`

After a selection, the sentence resolves immediately and shows a temporary confirmation such as `Using feminine for Maya · Change`. The choice also resolves other currently ambiguous messages for that participant. `Change` restores the choice, and the confirmation disappears after the next sent or received message.

### How the preference is remembered

- A person's own form is account-wide and takes priority.
- A partner choice is a private fallback for that one-to-one relationship; it never changes the partner's profile.
- Conversation tone—Informal or Respectful—is independent and remembered per chat.
- The first clear form somebody writes is learned silently.
- The first later contradiction reopens the chooser without calling either form a mistake.
- If the contradiction is ignored, the authored sentence stays unchanged and the stored preference returns to Not set.
- V1 offers feminine and masculine where the target language requires them. English and Turkish can remain naturally neutral; Blab does not invent awkward neutral Ukrainian wording.

### Current state

Recently built:

- Local account-wide self form, private partner fallback, and per-chat tone.
- Profile and chat entry points for Translation preferences.
- Inline linked alternatives, the non-modal chooser, in-place resolution, and Change.
- A translation contract that carries the relevant participant, tone, and linked grammatical alternatives.

Still to finish before launch:

- Restore the preference correctly from persisted translation cache.
- Complete authored-form contradiction behavior.
- Localize all new interface copy.
- Run the full 11-language content and device QA, including linked agreement in French and Hindi, third-person Tamil, and no unnecessary chooser in English or Turkish.

## Current launch status

The app already has a substantial working foundation, but it is not yet ready for public Play Store release. The highest-risk remaining gates are the full learning-message lifecycle, grammatical-form completion, invite continuity, production signing and verified links, release Google sign-in, offline/failure recovery, report/block and crash-report checks, legal/store assets, and the required closed-testing period.

The living status and checkboxes are maintained in [`progress.html`](./progress.html). A task is marked officially complete only after the owner manually tests it and confirms it passed.

## Source specifications

- [Canonical product specification](./tasks/prd-blab.md)
- [Technical specification](./tasks/tech-spec.md)
- [Detailed build progress](./tasks/progress.md)
- [Message lifecycle and translating state](./docs/superpowers/specs/2026-08-12-translating-state-animation-design.md)
- [Grammatical-form preferences](./docs/superpowers/specs/2026-08-14-grammatical-form-preferences-design.md)
