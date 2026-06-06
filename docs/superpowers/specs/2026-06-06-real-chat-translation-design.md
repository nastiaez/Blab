# Real-chat translation — Tamil → English (first slice)

**Date:** 2026-06-06
**Phase:** 2 (Backend wiring) — first slice of Step 2.7
**Status:** Approved, ready for plan
**Relates to:** Step 2.7 (translation dictionary + tokenizer), PRD US-014 (subtitle), US-018 (word popup), FR-23 (per-chat translation toggle), Resolved Decision #17 (Anthropic Haiku via edge function)

---

## Problem

Translation works only in portfolio mode. Real chats between two paired
accounts render incoming foreign-language bubbles as plain text — no
tappable words, no English subtitle. Step 2.7 in `progress.md` originally
specified bundled JSON dictionaries + tokenizers for Tamil ↔ English and
Ukrainian ↔ English. Re-evaluated 2026-06-06: Tamil's agglutinative
morphology, plus names + typos, makes flat surface-form dictionaries miss
most words. LLM-backed translation (already used by portfolio mode) gives
~100% coverage at ~$0.001/message, with a 1–2s shimmer that matches the
portfolio UX. This spec adopts the LLM path for real chats.

Goal of **this slice**: when the chat partner sends a Tamil message, the
incoming bubble renders the same shape portfolio mode already produces —
tappable Tamil tokens + sentence subtitle + word popup. No new UI widgets;
the existing `TranslationSubtitle` and `MessageText` + `WordPopup` widgets
get fed real-chat data.

Out of scope for this slice (next sessions):
- English → Tamil direction (Aswin viewing Nastia's outgoing messages)
- Ukrainian ↔ English
- Other 9 languages — they continue rendering as plain text; "coming soon"
  copy lands later
- DB-side cache (`messages.translation` + `messages.tokens` columns +
  edge-function writeback) — tonight's cache is in-memory only

---

## Behavior

1. Nastia opens her chat with Aswin. Chat learning language = Tamil.
2. Aswin's existing Tamil messages stream in via Supabase (unchanged).
3. For each incoming Tamil bubble: the in-memory translation cache for that
   message id is checked.
4. **Cache miss** → bubble renders with a shimmer subtitle (same widget as
   portfolio mode). Client calls edge function `translate-message` with
   `text`, `sourceLang: 'ta'`, `targetLang: 'en'`.
5. ~0.5–2s later, response arrives. Cache entry filled. Bubble re-renders
   with Tamil tokens + English sentence subtitle. Tapping any token opens
   the existing word popup with English gloss + romanization + speaker.
6. **Failure** (4s timeout, 5xx, malformed JSON, offline) → cache entry =
   error. Bubble renders the original Tamil plain (no tappable tokens) +
   muted italic "Translation unavailable" subtitle. Same widget as portfolio
   failure path.
7. App restart → cache empties. Same messages translate again on next view.
   (DB-side persistence is a follow-up slice.)
8. Chats with learning language ≠ `ta` (other 10 languages) render plain,
   no translation row, no shimmer, no network call. Same as today's
   behavior.

---

## Architecture

Four units; two new, one expanded, one reused.

### 1. Edge function `translate-message`

**Where:** new `supabase/functions/translate-message/index.ts`. Clone of
`translate-portfolio` with two changes:

- Accepts `sourceLang` and `targetLang` in the POST body (instead of
  hardcoded English → Tamil).
- System prompt parametrized on both languages, instructs Claude to return
  `{translation, tokens[]}` where each token's `gloss` is in `targetLang`
  and `romanization` is present when the source script is non-Latin.

`translate-portfolio` is left untouched so portfolio mode keeps working
without redeploy risk. Both functions can be unified in a later refactor.

**Caps:** 400-char input, 4s server-side timeout, no auth required on the
function itself (Supabase JWT verified by `--no-verify-jwt` flag stripped —
JWT verification is on; users must be signed in to call it).

### 2. Flutter client: `MessageTranslator` service + provider

**Where:** new `lib/features/chat/services/message_translator.dart`.

Mirror of `PortfolioTranslator`:

- `translate({required text, required sourceLang, required targetLang})`
  returns `TranslationResult` (reuses the existing model from portfolio
  code path).
- 4s client-side timeout, throws `MessageTranslationFailed(reason)` on
  empty input / timeout / invoke error / shape mismatch.
- Riverpod `messageTranslatorProvider` exposes it; injectable invoker for
  tests.

### 3. Translation cache: `messageTranslationsProvider`

**Where:** new `lib/features/chat/state/message_translations_state.dart`.

Per-chat `NotifierProvider.family<MessageTranslationsNotifier,
Map<String, AsyncValue<TranslationResult>>, String>` keyed by message id.

- `ensure(messageId, text, sourceLang, targetLang)` — if entry exists,
  no-op. Otherwise sets entry to `AsyncLoading`, fires the translator,
  writes `AsyncData` or `AsyncError` on completion.
- `get(messageId)` — returns current entry or null.
- In-memory only this slice. No persistence layer. Dies on `dispose`.

### 4. Chat bubble integration

**Where:** edit `lib/features/chat/widgets/chat_screen.dart` (or wherever
`_Bubble` lives — to be located in plan).

For incoming bubbles only:

- Resolve message language: from the chat's partner-teach language
  (`Chat.partnerTeachLanguage`, derivable from the existing chat membership
  data). If equal to my interface language, render plain — no translation
  row.
- If learning language is in the supported set (tonight: `{ta}`), call
  `messageTranslationsProvider(chatId).notifier.ensure(...)` inside a
  `useEffect`-style hook (or `ref.listen` on first build of the bubble).
- Render bubble text via existing `MessageText` widget. When tokens
  available, pass them in for tappable spans. When loading or missing,
  render plain text.
- Render translation row via existing `TranslationSubtitle` widget,
  driven by the cache entry's `AsyncValue` state: loading → shimmer,
  data → sentence text, error → muted "Translation unavailable".
- `showTranslationsProvider(chatId)` toggle still gates the row's
  visibility (FR-23).

No schema changes. No new widgets. No DB migration.

---

## Data shapes

`TranslationResult` (already exists in portfolio code path):

```dart
class TranslationResult {
  final String translation;          // sentence-level English
  final List<MessageToken> tokens;   // per-word tokens
}
```

Edge function request body:

```json
{ "text": "காலை வணக்கம், எப்படி இருக்கீங்க?",
  "sourceLang": "ta",
  "targetLang": "en" }
```

Edge function response (success):

```json
{
  "translation": "Good morning, how are you?",
  "tokens": [
    { "text": "காலை", "gloss": "morning", "romanization": "kaalai" },
    { "text": "வணக்கம்", "gloss": "greetings", "romanization": "vanakkam" },
    { "text": ",", "gloss": null, "romanization": null },
    { "text": "எப்படி", "gloss": "how", "romanization": "eppadi" },
    { "text": "இருக்கீங்க", "gloss": "are you", "romanization": "irukkeenga" },
    { "text": "?", "gloss": null, "romanization": null }
  ]
}
```

Punctuation tokens carry null gloss/romanization and render as plain
non-tappable text (existing `MessageText` already supports this).

---

## Error handling

| Condition | UX |
|---|---|
| Offline (DNS fail, socket error) | Bubble renders plain Tamil + "Translation unavailable" subtitle |
| 4s timeout | Same as offline |
| Edge fn 5xx | Same as offline |
| Malformed JSON in response | Same as offline |
| Empty input | No-op, no network call |
| User toggles `showTranslations` off mid-fetch | Fetch completes silently, result cached, subtitle hidden by toggle |

No retry button this slice. Re-entering the chat screen re-fires
translation (cache lives on the chat screen's provider scope, dies on
dispose). DB persistence will fix this.

---

## Testing

- `MessageTranslator`: success → returns parsed result; timeout → throws
  `MessageTranslationFailed(timeout)`; malformed JSON → throws
  `MessageTranslationFailed(invoke)`; empty input → throws
  `MessageTranslationFailed(empty)`. Injectable fake invoker; no real
  network.
- `MessageTranslationsNotifier`: `ensure` on empty cache sets loading then
  data; `ensure` on existing entry no-ops (translator not re-called);
  separate message ids cache independently; error result cached as
  `AsyncError`.
- Bubble widget: incoming Tamil + loading state → shimmer subtitle
  rendered, plain text bubble; incoming Tamil + data state → tokens fed to
  `MessageText`, sentence in subtitle; incoming Tamil + error state →
  plain text + muted "Translation unavailable"; learning language ≠ ta →
  no translation row, no `ensure` call.

`flutter analyze` clean. `flutter test` green.

---

## Deployment + verification

1. `supabase functions deploy translate-message` from a logged-in CLI.
   `ANTHROPIC_API_KEY` is already set as a secret on the project (used by
   `translate-portfolio`); no new secret needed.
2. Build + install on Samsung S931B.
3. Live verification with two real accounts already paired (Nastia + Aswin
   demo accounts): Aswin sends a Tamil message → Nastia's view shows
   shimmer subtitle → swaps to Tamil tokens + English subtitle within ~2s;
   tap a token → word popup shows English + romanization + working
   speaker.
4. Airplane mode on Nastia's phone → Aswin sends another Tamil message
   (queued for Nastia to receive when back online) — for this slice,
   simulate by sending Nastia a Tamil message normally first, then turning
   airplane mode on and re-entering the chat screen: bubble renders plain
   + "Translation unavailable".
5. Toggle ⋯ → Show translations off → translation row disappears under
   every bubble. On → reappears.
6. Other 9 languages: pair a second chat (e.g. with Spanish learning
   language) and confirm no shimmer fires, no network call, plain
   rendering.

---

## Open questions

None.

---

## Resolved decisions logged elsewhere

- Tech-spec Resolved Decision #17 (Anthropic Haiku via Supabase Edge fn)
  already covers the translation backend choice.
- `progress.md` Step 2.7 to be amended next session to reflect the LLM
  pivot away from bundled dictionaries.
