# Portfolio mode — live English → Tamil send

**Date:** 2026-06-02
**Phase:** 2.5 (Portfolio polish, Track A)
**Status:** Approved, ready for plan
**Relates to:** Step A2 (portfolio mode), PRD US-013 (compose), US-014 (subtitle), US-018 (word popup), FR-23 (per-chat translation)

---

## Problem

Portfolio mode currently ships a curated 7-message Tamil↔English chat with
`Aswin`. The send button is disabled in code: `ChatNotifier.addOutgoing`
early-returns when `portfolioModeProvider` is on
(`lib/features/chat/state/chat_state.dart:79`). For live demos this is dead —
the demo viewer can't try the product, only look at it.

Goal: in portfolio mode, the user types **any English** sentence, sends it,
and sees it appear as an outgoing bubble with a real Tamil translation
subtitle + tappable Tamil tokens (English gloss + romanization). Quality
must match the hand-curated incoming bubbles so the word popup feels real.

This is portfolio mode only. The Supabase send path off-mode is untouched.

---

## Behavior (the demo flow)

1. Portfolio toggle on. User opens Aswin chat (the only one).
2. Types English in the input bar (e.g. *"running late tonight, can we move
   to 8?"*).
3. Taps send.
4. Outgoing orange bubble appears **immediately**. Translation subtitle slot
   shows a single-line shimmer placeholder.
5. ~0.5–2s later: shimmer fades to Tamil sentence. Tapping any Tamil word
   opens the existing word popup with English gloss + romanization.
6. Read tick on outgoing bubble flips delivered → read after 1.5s (matches
   existing mock behavior; orthogonal to translation).
7. On wifi loss or translation failure: bubble stays in place, subtitle
   renders muted italic **"Translation unavailable"**. No red tick, no
   failed-message sheet. Demo continues.
8. New bubbles are in-memory only. App restart reseeds the curated 7. Toggle
   off → mutations discarded, real Supabase chats return.

---

## Architecture

Three new units + small edits to existing ones.

### 1. Translation service (cloud helper)

**Where:** new Supabase Edge Function
`supabase/functions/translate-portfolio/index.ts`.

**Why Edge Function:** API key must not ship in the Flutter binary. Supabase
is already the backend; reusing it avoids a separate proxy. Edge runtime is
fine for a sub-2s LLM call.

**Why Anthropic Claude Haiku 4.5:** cheapest fast model that reliably emits
structured JSON, already in our toolchain, single-call covers sentence +
tokens + romanization. Decision logged in
`tasks/tech-spec.md` § Resolved Decisions.

**Contract:**

- Method: `POST`
- Auth: anonymous (portfolio mode users may not have an account)
- Request body:
  ```json
  { "text": "running late tonight, can we move to 8?", "target": "ta" }
  ```
- Response (200):
  ```json
  {
    "translation": "இன்று இரவு தாமதமாகிறது, 8 மணிக்கு மாற்றலாமா?",
    "tokens": [
      {"text": "இன்று", "english": "Tonight", "roman": "Iṉṟu", "isContent": true},
      {"text": " ", "isContent": false},
      {"text": "இரவு", "english": "Night", "roman": "Iravu", "isContent": true},
      ...
    ]
  }
  ```
- Error: 4xx/5xx with `{ "error": "<code>" }`. Client treats any non-200 as
  unavailable.

**Prompt (sketch):**

> You translate English into Tamil for a language-learning app. Return
> strict JSON: `{"translation": "<Tamil sentence>", "tokens": [...]}`.
> Tokens are an ordered list that, concatenated by `text`, exactly reproduce
> the Tamil sentence. Content tokens (`isContent: true`) carry `english`
> (1–3 word gloss) and `roman` (IAST-style transliteration). Punctuation
> and whitespace tokens have `isContent: false` and omit `english`/`roman`.

**Abuse:** anonymous + rate limit by IP at the Supabase function level
(default config), plus a hard `MAX_CHARS=400` guard in the function. No
authn token plumbing — portfolio mode is a public demo by design.

**Target language:** request takes `target` but v1 only handles `ta`. Other
codes return 400 with `error: "unsupported_target"`.

### 2. Mutable portfolio messages

**Where:** new `lib/shared/state/portfolio_messages_state.dart`.

**What:** a `NotifierProvider.family<List<Message>, String>` keyed by chat
id. Seeds from the existing curated list in
`lib/shared/data/portfolio_data.dart`. Exposes:

- `append(Message m)` — add a message
- `updateById(String id, Message Function(Message) f)` — in-place swap, for
  upgrading a pending translation to the real one
- `reset()` — restore the curated seed (used when portfolio mode flips
  on→off or app launches)

The existing `portfolioMessages(chatId)` function becomes the seed source;
the notifier owns mutation.

### 3. Translator client

**Where:** new `lib/shared/services/portfolio_translator.dart`.

**API:**

```dart
class PortfolioTranslator {
  Future<PortfolioTranslation> translate(String englishText);
}

class PortfolioTranslation {
  final String tamil;
  final List<MessageToken> tokens;
}
```

Calls `Supabase.instance.client.functions.invoke('translate-portfolio',
body: {'text': englishText, 'target': 'ta'})`. Wraps the result in a typed
record. 4s timeout. Any failure (timeout, non-200, parse error) throws a
single `PortfolioTranslationFailed` exception — caller decides how to render.

Exposed via `portfolioTranslatorProvider` (Riverpod) so tests can inject a
fake.

### 4. Chat state branching

**Where:** edit `lib/features/chat/state/chat_state.dart`.

`ChatNotifier.build`: when portfolio mode is on, watch the new
`portfolioMessagesProvider(chatId)` and yield its value (currently yields a
one-shot `portfolioMessages(chatId)`).

`ChatNotifier.addOutgoing`: when portfolio mode is on (currently early
returns), instead:

1. Build a `Message` with `status: delivered`, `translation: ''` (empty
   string = pending sentinel), empty token list.
2. `append` it to `portfolioMessagesProvider(chatId)`.
3. Kick off `PortfolioTranslator.translate(text)`.
4. On success: `updateById` to swap in the translation + tokens.
5. On failure: `updateById` to set `translation: '__unavailable__'` (or a
   dedicated nullable flag — see Open below) and empty tokens.
6. After 1.5s, flip status delivered → read (matches the existing mock for
   curated outgoing bubbles).

No pending-sends queue, no edge-function via the real chat service. The
real `addOutgoing` Supabase path is unchanged off-mode.

### 5. Translation subtitle states

**Where:** edit the bubble widget that renders the translation line under
outgoing messages (in `lib/features/chat/widgets/`).

Three render states driven by the existing `Message` fields:

| State        | Trigger                                | Render                                           |
| ------------ | -------------------------------------- | ------------------------------------------------ |
| pending      | outgoing + `translation` is empty      | 1-line shimmer placeholder, ~16px tall           |
| ready        | `translation` non-empty, no sentinel   | Tamil text, tappable tokens (existing behavior)  |
| unavailable  | `translation == '__unavailable__'`    | muted italic "Translation unavailable", no taps  |

The shimmer = a thin gradient sweep on a rounded rect. No new package — use
a `LinearGradient` inside an `AnimatedBuilder` (small custom widget,
~40 lines). Matches Flutter app's no-extra-deps preference.

Existing `showTranslationsProvider` toggle still hides the whole subtitle
row regardless of state (FR-23 preserved).

---

## Files touched

**New:**

- `supabase/functions/translate-portfolio/index.ts`
- `lib/shared/services/portfolio_translator.dart`
- `lib/shared/state/portfolio_messages_state.dart`
- `lib/features/chat/widgets/translation_subtitle.dart` (extract from
  existing bubble widget if not already extracted, with the 3 states)

**Edited:**

- `lib/features/chat/state/chat_state.dart` — portfolio branch in `build` +
  `addOutgoing`
- `lib/shared/data/portfolio_data.dart` — expose seed list as a top-level
  function the notifier can call (cheap rename if needed)
- bubble widget call site — render through `translation_subtitle.dart`
- `tasks/tech-spec.md` — log Anthropic Haiku 4.5 + Supabase Edge Function as
  Resolved Decision
- `tasks/progress.md` — add Step A2.5 under Phase 2.5 with the Done-when
  rubric

---

## Testing

- **Unit:** fake `PortfolioTranslator` (returns canned result / throws) +
  pump `addOutgoing` → assert pending → ready transition; assert failure →
  unavailable sentinel.
- **Unit:** portfolio messages notifier `append` / `updateById` / `reset`.
- **Widget:** translation subtitle renders correct state for each of
  pending / ready / unavailable.
- **Manual / device:** type 3 English sentences during demo, observe
  shimmer→Tamil transition, tap a word in the new bubble, confirm popup.
  Toggle wifi off, send, confirm "Translation unavailable" subtitle.

No live Edge Function call in unit tests — translator is mocked. Edge
Function gets a thin integration test via the Supabase CLI before
deployment.

---

## Out of scope (firm)

- Off-mode chats. Real Supabase send path is unchanged.
- Languages other than Tamil. Other portfolio chats don't exist yet; v2.
- Persistence across app restart. Mutations are in-memory; reseed on launch.
- Authn / per-user rate limiting on the Edge Function. Portfolio mode is a
  public demo by design; basic IP rate limit + 400-char cap is the entire
  abuse posture.
- Cost monitoring / analytics on the Edge Function. Pennies per demo, not
  worth the plumbing for v1.

---

## Open

- **Unavailable sentinel:** the design above uses the magic string
  `'__unavailable__'` in `Message.translation`. Cleaner would be a new
  optional `translationState` enum on `Message` (`pending` / `ready` /
  `unavailable`), with `translation` always being the literal text or
  empty. Decision left for the implementation plan — both work; the plan
  should pick whichever needs fewer migrations through the existing widget
  tree.

---

## Done when

(For the corresponding `progress.md` step.)

1. Portfolio mode on, Aswin chat: typing any English sentence + sending
   shows an outgoing bubble with shimmer subtitle, then a Tamil translation
   with tappable tokens that match the word-popup format.
2. Tapping a token in the new bubble opens the existing word popup with
   English gloss + romanization.
3. With wifi off, the same flow ends in a muted "Translation unavailable"
   subtitle (no failed-message sheet, no red tick).
4. Toggling portfolio mode off → on between sends resets the chat to the
   curated 7-message seed.
5. `flutter analyze` clean, `flutter test` green, manual device verification
   logged in `progress.md` Changelog.
