# Tech Spec: Blab

> **BLA-17 approval16778 ·29 October2026:** corrected native implementation clip accepted; scoped current-main reconciliation, commit and integration authorized after verification. Message/text tap opens separate matching-cream anchored functions/reactions; composer retained, scrolling finite and panels fixed in stable viewport. Writing-field tap immediately deselects/closes both panels without changing native keyboard/draft behavior; Edit remains separate. Newer mention identity/styling/picker-overlay behavior must survive. Distribution/uploads/notices/tester sends remain held. Tiny/top fallback, universal readability and async lifecycle are not inferred approved. Evidence: [integration QA](../docs/qa/2026-10-29-bla17-integration/README.md).

> **Scope:** how we build Blab. The *what* lives in [`prd-blab.md`](./prd-blab.md) — that PRD is the source of truth for product behavior. This document only covers technology, architecture, and engineering conventions. If the two disagree on product behavior, the PRD wins; if they disagree on tech choices, this spec wins.

---

## Stack

- **Framework:** Flutter (stable channel), Dart 3+
- **Targets:** Android first, iOS second
  - Phase 1: Android-only builds, ship to physical device + emulator
  - Phase 2: iOS parity — no Android-only APIs without an iOS equivalent path
- **Single codebase, single design system** — see § Design Fidelity below

---

## Platform Targets

| Platform | Phase | Min version | Notes |
|----------|-------|-------------|-------|
| Android  | 1     | API 24 (Android 7.0) | Covers ~97% of devices |
| iOS      | 2     | iOS 15      | Current Firebase Core/Messaging iOS packages require iOS 15; aligned during first iOS setup, 2026-10-15 |

Owner clarification, 2026-10-13: retain the current Blab visual language and assets while composing reusable Flutter Material 3 controls. Android uses genuine Material navigation, SDK-standard page transitions and system/predictive Back; do not recreate these mechanisms with custom replicas. Minimal unavoidable geometry changes require screenshot/journey approval before integration. Implementation is in progress on `feat/material3-migration`, not released.

---

## Project Layout

```
lib/
  main.dart                  // app entry, theme, root router
  app/
    router.dart              // route definitions (one route per PRD flow)
    theme.dart               // colors, typography, radii — pulled from prototype.html
  features/
    onboarding/              // Welcome, Learn, setup resolver, name, language
    auth/                    // Signup, login, recovery, shared auth controls
    chats/                   // Flow 2 (US-006…US-012)
    chat/                    // Flow 3 + 4 chat surface (US-013…US-023, US-028)
    invite/                  // Flow 4 invite landing + join (US-024…US-027)
    profile/                 // Profile, Edit profile, Change password (US-010…US-012)
  shared/
    widgets/                 // BottomSheet, TappableWord, ReadReceipts, etc.
    models/
    services/                // api, storage, auth client
  l10n/                      // interface language strings (FR-3)
test/
integration_test/
android/
ios/
```

One folder per PRD flow. Each feature folder owns its widgets, state, and screen files; cross-feature widgets live under `shared/widgets`.

---

## State Management

**Decision: Riverpod** (`flutter_riverpod`). Locked 2026-05-25.

Conventions:
- Use `riverpod_generator` + `riverpod_annotation` for codegen — typed providers, no string keys.
- Group providers by feature folder (`features/<flow>/providers/`), not centrally.
- Notifier classes for mutable state; `Provider` / `FutureProvider` / `StreamProvider` for derived/async.
- No `BuildContext`-passing for state. No `ChangeNotifier` mixed in.

State scoping rule from the PRD: **Phone 3 and Phone 4 keep separate translation-toggle state** (FR-23). In Flutter terms, the "show translations" flag is per-chat — model as a `NotifierProvider.family<bool, ChatId>` (or equivalent codegen form), never a global setting.

---

## Navigation

- **`go_router`** for declarative routes, deep links (needed for invite links — US-024), and nested navigation
- Bottom sheets stay imperative via `showModalBottomSheet` — they aren't routes
- One top-level route per PRD flow; nested routes for sub-screens (Edit profile, Change password, Forgot password)

Invite links (US-024) must be reachable from a cold app launch AND from a web landing → app handoff. Use Android App Links (Phase 1) + Universal Links (Phase 2).

---

## Backend

**Decision: Supabase.** Locked 2026-05-25.

Service mapping:

| Need | Supabase product |
|------|------------------|
| Email + password auth, Google SSO, password reset | **Supabase Auth** (`supabase_flutter` package); Apple follows in the iOS phase |
| Persistent storage (users, chats, messages, invite links) | **Supabase Postgres** with Row-Level Security (RLS) |
| Real-time chat transport (US-015, US-016) | **Supabase Realtime** — Postgres change streams + Broadcast channels for typing/presence (if added later) |
| Avatar uploads (US-011) | **Supabase Storage** |
| Personal invite link reusable until owner regeneration, with no time expiry (FR-4) | Postgres table + RLS policy + authenticated RPCs for token mint/validate/rotate |
| Push notifications (US-038, FR-29) | **FCM via Supabase Edge Function** trigger (Supabase has no native push) |

Conventions:
- One Supabase project per environment: `dev`, `staging`, `prod`.
- All tables get RLS on day one. No service-role keys shipped in the app — Flutter uses anon key only.
- Migrations live under `supabase/migrations/` (Supabase CLI). PR-reviewed; never edit prod via dashboard.
- Generate Dart types from the Postgres schema with `supabase gen types` → checked in under `lib/shared/models/db/`.

**Out of scope for backend:** language matching/discovery, payments, voice/video, and AI-generated conversation partners. Group-chat backend work is limited to the approved BLA-14 specification (`docs/specs/2026-10-19-group-feature.md`); do not infer broader social/discovery behavior. Message translation is implemented through the authenticated `translate-message` Edge Function and OpenRouter.

Message translation and word metadata come from the authenticated translation service and are cached by message, learning language, and primary known language. The popup itself makes no network or model request: it reads the cached per-word gloss and Latin-script transliteration, while audio stays on-device TTS (FR-11, FR-24, FR-33).

---

## Design Fidelity

The app has more than one historical prototype, so onboarding/auth uses an explicit source hierarchy:

1. approved product behavior in `docs/superpowers/specs/2026-09-30-onboarding-auth-refresh-design.md`;
2. the latest approved Paper artboard for default-state composition and copy;
3. the current onboarding HTML/CSS/JavaScript for motion, focus, loading, and validation behavior;
4. the existing Flutter app for retained authentication, callback, session, locale, profile, and invite behavior.

Older prototype documents and removed photo/multi-language screens are historical only. Other app surfaces continue to use their own approved specs and incumbent Flutter implementation.

Onboarding/auth uses a scoped native Flutter component family with cream `#FAF7F2`, action orange `#F88C5A`, ink `#1F3340`, 56 px controls, 16 px radii, and system typography. This does not silently retheme Chats or Profile.

General translation rules:

| Prototype | Flutter |
|-----------|---------|
| Approved surface color token | Shared Flutter token for that surface family |
| 375×780 phone shell | Real device safe areas — drop fixed dimensions |
| Inline `onclick` handlers | Widget callbacks, never global functions |
| DOM `display:none` toggling | Widget tree rebuilds via state |
| Bottom sheet `*Sheet` + `*Backdrop` | `showModalBottomSheet` (handles scrim) |
| Tappable word `<span>` | `RichText` + `TextSpan` with `TapGestureRecognizer` |
| Word popup clamped to phone bounds (FR-12) | `OverlayEntry` positioned via `CompositedTransformFollower` |
| Receipt assets | Clock while sending; supplied single gray check after acceptance/device receipt; supplied double gray check on read |
| Auto-growing textarea (US-023) | `TextField` with `maxLines: null` + `minLines: 1` |
| Long-press 500ms (US-019, US-020) | `GestureDetector(onLongPress: …)` |
| Date dividers ("Today") | Section headers in `ListView.builder` |

The prototype's `id`/class names are not API — don't carry them into Dart.

---

## Tooling

- **Lints:** `flutter_lints` (default) + opt into stricter rules incrementally
- **Formatting:** `dart format` enforced in pre-commit
- **Package manager:** `pub` (built in)
- **Build:** `flutter build apk` (debug), `flutter build appbundle` (release for Play Store)
- **Local run:** `flutter run -d <device-id>`; list devices via `flutter devices`

---

## Testing

- **Unit tests:** `flutter_test`, one file per non-trivial pure-Dart unit
- **Widget tests:** golden tests for hero screens (auth, chat list, chat view) once design is locked
- **Integration tests:** `integration_test` package — cover the 4 PRD flows end-to-end (sign up → invite → join → chat)
- Acceptance-criteria checklists in `prd-blab.md` map 1:1 to integration test cases

---

## Internationalization

- `flutter_localizations` + ARB files under `lib/l10n/`
- Launch interface locales = English (`en`), Ukrainian (`uk`), German (`de`), and Spanish (`es`); English is the synchronous default and invalid/missing-value fallback. Ukrainian interface copy uses informal singular address (`ти` forms)
- The guest preference is device-local; signed-in preferences are cached under an account-scoped key and persisted through a self-only profile RPC
- **Interface Language** controls app chrome only. **Primary Known Language** controls Normal-mode translations and word descriptions. **Learning Language** controls Practice-mode output plus word and sentence audio. Do not conflate them.
- Learning-aid cache identity is currently `(message_id, target_lang, interface_lang)`, where the legacy `interface_lang` storage field carries the reader's primary Known Language for message output and word descriptions. Authored text remains authoritative in `messages.body`; each row stores learning-language output, primary-known-language output, detected source, tokens, and correction analysis. Correction analysis remains internal data and is not presented as an explanation popup. Real Interface Language is not part of learning-aid cache identity and changes app chrome only
- Retryable learning-aid failures remain client-local `AsyncError` entries. Manual Retry clears only the failed `(message_id, target_lang, primary_known_lang)` variant before re-running the server-authoritative cache/function flow
- Message/text tap opens BLA-17 anchored panels; message word lookup and long-press menu entry are removed. Composer and finite whole-chat scrolling are retained; writing-field tap immediately closes active selection. Normal may reveal exact authorized `messages.body` through Original; Practice uses the cached primary-known-language line and Listen instead

---

## CI / Release

Existing GitHub Actions validate formatting, shell syntax, Flutter analysis/tests, disposable Supabase integration and a synthetic Android release compile. The synthetic signing/config artifact is non-distributable.

Private delivery uses the existing Firebase App Tester channel. Worktree implementation → numbered screenshots and journey review → explicit owner approval → merge/synchronize main → signed integrated-main Android verification → distribute and download-back hash verification. Never release a feature-worktree or CI synthetic artifact.

---

## Crash Reporting + Observability

**Decision: Sentry** (`sentry_flutter`). Locked 2026-05-25.

- Initialize in `main.dart` before `runApp`; wrap with `SentryFlutter.init` runner.
- Capture: unhandled errors, Flutter framework errors, Dart isolate errors, network 5xx, performance traces for cold-start and chat-view first-paint.
- DSN per environment (dev / staging / prod) via build-time `--dart-define`.
- PII: scrub email + message bodies before send. User id only.
- Source maps / debug symbols uploaded on release builds via Sentry CLI step in CI.

## Resolved Decisions

- **2026-10-16 — Retryable auth refresh failures (US-031):** Supabase `AuthRetryableFetchException` is a recoverable transport/server failure, not a session transition or a Flutter crash. The root listener retains the session without reporting a fatal error; the session provider ignores only this typed stream error, preserving its last value. Genuine sign-out and token-refresh events continue to propagate, unexpected errors remain reported, and retryable errors cannot be classified as revoked based on message text. Rely on the SDK's existing bounded retry/auto-refresh rather than adding a competing retry loop. No language preferences, cache ownership, navigation, or interface copy change.

- **2026-10-14 — Stream command authority (implementation in progress):** do not rely on Stream's before-send webhook for mandatory Blab authorization: the vendor documents fail-open behavior on timeout/unavailability. Route mutations through authenticated Blab endpoints that enforce membership, symmetric blocking, author identity, the edit window and idempotency; restrict final Stream client permissions accordingly. Stream remains canonical for message contents; a server-only, source-versioned learning projection feeds existing private translation contracts. Signed webhook identities are durably deduplicated; reconcile against current canonical Stream snapshots rather than trusting arrival order. Immediate asynchronous dispatch plus periodic recovery, no AI on delivery path. Existing chats stay Supabase-owned until per-chat migration is explicitly verified and activated.
 (log)

2026-10-14 owner-authorized migration, in progress: Stream Chat will own original chat messages, delivery/history/sync, reactions and receipt transport; Supabase retains identity, private language preferences, learning-era state and translation/word-help services. Use the Stream low-level Flutter client with existing Blab presentation, not a vendor UI kit. Signed server-issued Stream tokens derive from authenticated Supabase identity; no client-supplied impersonation. Event-driven, idempotent translation jobs use immutable source/version and Stream message IDs. No production history cutover or main/tester integration until reviewed Android journeys pass and owner approves. Free account/app setup authorized; paid subscriptions are not.

1. ✅ **State management:** Riverpod — locked 2026-05-25
2. ✅ **Backend:** Supabase (Auth + Postgres + Realtime + Storage + Edge Functions; FCM via edge function for push) — locked 2026-05-25
3. ✅ **Real-time transport:** Supabase Realtime (Postgres change streams) — locked 2026-05-25, follows from #2
4. ✅ **Crash reporting:** Sentry (`sentry_flutter`) — locked 2026-05-25
5. ✅ **Supabase environments:** local Supabase for daily development, hosted staging ref `tpfksdljkfnenjfdbane`, and production ref `bhzcexhebjszwyqvcsxs`. Clients receive environment-specific public configuration at build time; no hosted URL or publishable key is embedded as a source fallback. Row-level security remains the data boundary. — revised 2026-07-21 by L-18
6. ✅ **Typography:** system fonts only (Roboto on Android, SF Pro on iOS). No custom typeface. Lighter app weight, no licensing, theme already uses the system stack. — locked 2026-05-28
7. ✅ **Brand color direction:** orange `#D4694A` is the long-term brand color; purple `#5B4FE8` stays as in-app UI primary until full brand-guidelines pass swaps everything in one shot. Icon + splash already orange. — locked 2026-05-28
8. ✅ **Privacy posture (Signal-style symmetric toggles):** Typing indicators and Read receipts ship as per-user toggles, both default ON, both symmetric (OFF = client never broadcasts the event AND user does not see partner's). Online / "last seen" presence is **not built as a feature at all** (no toggle, no opt-out, simply absent). Key recovery scheme deferred to V2 — V1 = reinstall wipes history. Full posture in PRD § Privacy posture. — locked 2026-05-28
9. ✅ **Supabase region:** production and staging are in EU/Ireland (`eu-west-1`). Keep the healthy production project for launch; exact-region documentation must match deployed reality. — revised 2026-07-21 by L-18
10. ✅ **Edit / delete time windows:** Edit = 24h from send time (Signal-style); after that the Edit row is hidden from the long-press sheet. Delete = no time limit, sender can delete any sent message at any time, propagates to recipient. — locked 2026-05-28
11. ✅ **TTS source:** V1 on-device only (Flutter TTS via OS engines). Disabled state = icon dim 40%, no tap, no tooltip, no text. V2 evaluate cloud TTS / recorded human audio for languages where on-device quality is weak (Tamil, Ukrainian, Hindi). — locked 2026-05-28
12. ✅ **Multiple language exchanges per user:** Yes, per-chat. Each chat row owns its `learning_language_code` + `teaching_language_code`. Profile hero shows the "primary" (most-active) as a hint. — locked 2026-05-28
13. ✅ **Invite link policy:** Valid until a single *successful* claim, with no time expiry. Multiple clicks before claim are allowed. Once claimed, link returns the appropriate existing-chat or "already claimed" state (US-037). Removing the TTL prevents delayed and offline shares from becoming invalid unexpectedly. — revised 2026-09-07
14. ✅ **Interface-language behavior:** English, Ukrainian, German, and Spanish are the launch interface locales, with English default/fallback and account-scoped persistence. Interface language controls chrome and word-definition copy; it is not a message-translation target. The reader's primary known language controls Normal's unknown-language translation and Practice's temporary second line. Authored text remains authoritative and is available through Normal's Original action whenever displayed text differs. — revised 2026-09-30 by the correction-explanation removal
15. ✅ **Log-out UX:** Confirm dialog before sign out ("Log out?" / Cancel + Log out). Signal pattern. — locked 2026-05-28
16. ✅ **Palette + type tokens (final v1 swap):** Brand `#D4694A` (press `#BB573B`, soft `#F3DAD0`). App canvas cream `#EFEBE2`. White surface for sheets + (per-screen) status-bar safe area. Ink `#1F3340`, stone `#9A9490`, line `#E4DCCC`. Input focus border `#E19680` (softer than brand to avoid alarm). Selected-row tint `#FAF1EC`. Avatars = deterministic warm swatch from `[#46281C, #917869, #BC6C4E, #788C73, #AF787D, #5F3C4B]` keyed by name; the former palette is retired and gradients remain excluded. Links use brand; chat receipt icons use the gray single/double-check contract in Decision #22. System fonts only (Roboto on Android, SF Pro on iOS — same as #6). The approved chat-only surface, mode-switch, and message-bubble exception is defined in `docs/superpowers/specs/2026-08-23-chat-practice-mode-ui-refresh-design.md`. — revised 2026-08-24
17. ⛔ **Portfolio-mode live translation backend (retired):** The historical public `translate-portfolio` demo endpoint was removed with L-13 after portfolio mode left the app. It must not be deployed for launch. Historical design remains in `docs/superpowers/specs/2026-06-02-portfolio-live-translate-design.md`. — retired 2026-07-17
18. ✅ **Launch translation security:** The Flutter client submits only a message ID to the JWT-verified `translate-message` Edge Function. Postgres derives the authorized source body and caller's learning language, enforces active membership plus the viewer's assigned language revision, and atomically reserves the approved per-account quota only on a cache miss. Only the server can write prepared translation packages, and writes compare both a SHA-256 source hash and viewer-language revision to reject edit or preference races. OpenRouter requests use `openai/gpt-4o-mini` through any eligible endpoint with `zdr=true`, `data_collection=deny`, fallback routing enabled, and required parameter support. The live ZDR catalog currently exposes this model through Azure, but Blab no longer hard-codes Azure as the only provider. — revised 2026-08-28 by US-044 / US-046
19. ✅ **Same-language writing correction:** The learning-aid contract returns exactly one mode: `translation` when source differs from the learning target, `correction` for a clear mistake in that target, or `none` for correct writing. Matching learning/interface locales reuse one cache row. The database snapshots whether both participants had the same Learning Language when each message is created. The author always sees correction marks; in Practice, the recipient sees the same marks only when that snapshot is true. Struck-through text has no explanation interaction for either participant, while corrected words retain standard word help. Mismatched and pre-feature messages remain clean, and later language changes never rewrite historical visibility. Ambiguous author corrections are labeled as possible and the provider must make the smallest defensible change without inventing missing meaning. — revised 2026-09-30 by approved shared-mistakes design
20. ✅ **Gallery attach picker:** custom in-app photo grid (`photo_manager`) replaces the Android system photo picker for the chat gallery-attach flow, matching WhatsApp/Telegram rather than the OS-branded picker sheet. Camera capture still goes through `image_picker`. Requires `READ_MEDIA_IMAGES` + `READ_MEDIA_VISUAL_USER_SELECTED` (Android 14+ partial-access) permissions declared in the manifest; a denied/partial state shows an in-app prompt with a link to system settings rather than failing silently. — locked 2026-08-06
21. ✅ **Grammatical-form memory:** Store only `not set | feminine | masculine`, with no confidence score or usage history. The user’s own value is account-scoped and authoritative; a partner value is a private one-to-one fallback and must never update the partner’s profile. Formality remains a separate per-chat value. Generated translations may return linked alternative segments plus the affected participant so the client can resolve all agreement changes together. — locked 2026-08-14 by US-042 / FR-34 / FR-35
22. ✅ **Launch message-action contract:** Follow `docs/superpowers/specs/2026-08-24-chat-ui-refresh-simple-long-press-design.md`. Word tap and message long press are separate; empty padding has no tap action. Copy/Reply resolve from the mode’s primary displayed text, while Edit always starts from authoritative authored text. Emoji/whitespace-only edits may reuse language-help output; any changed letter, number, or punctuation invalidates it. Receipt presentation is clock → single gray check → double gray check, with no distinct device-delivered visual. Confirmed Delete removes for both with no tombstone/Undo. Read-receipt OFF must suppress the outbound event rather than store a hidden read. — locked 2026-08-24
23. ✅ **Unresolved grammatical-form audit:** For a form-relevant target language, a generated translation with no alternatives cannot be accepted solely because the general translator returned `null`. While either participant’s form is `not set`, a focused server-side agreement audit must confirm that the sentence is naturally form-neutral or provide the exact shared prefix/suffix, the shortest complete feminine and masculine changing fragments, and the affected participant. A confirmed required choice must be present in the final cached translation; otherwise the request fails instead of silently storing one form. — locked 2026-08-24 by the on-device Ukrainian regression
24. ✅ **Message lifecycle motion:** Keep translation data in the existing locale-scoped Riverpod cache and render the lifecycle as a local, message-owned visual state machine. A delivered outgoing Practice message uses the 180/350 ms speed branches, a glyph-only shader wave, and sequential 120 ms clear → 150 ms measured empty resize → ≤220 ms land phases. Incoming language help is held behind neutral placeholder lines and uses the same speed branches and resolve phases, with the slow wave applied only to the lines; one pending incoming message has no separate status row, while simultaneous misses retain one count. Cached/off-screen results render final without replay, a finger scroll defers only the visible resolve, reduced motion swaps statically, and the client performs one quiet retry within one shared 10-second deadline. — locked 2026-09-11 by US-043 / US-044 / FR-36 / FR-38
25. ✅ **Prepared viewer packages + private language timeline:** A durable server-side job is created transactionally after message delivery for each participant. The worker derives that viewer's learning language, primary known language, form/tone preferences, source version, and private learning-language revision, then persists one viewer-specific package containing both Practice output and Normal fallback before announcing readiness. Completion uses compare-and-set on `(message, viewer, source version, language revision)`; a result can activate only in the message era it was prepared for. Work already attached to an older message finishes in that older language above the next private marker, while messages delivered after the marker use the new language. The original message is stored once; frequent switching adds only small revision events and does not duplicate the chat. Client-on-open remains a recovery path, not the primary trigger. — revised 2026-08-29 by the device-reviewed language-switch sequence
26. ✅ **Offline chat-media cache:** Supabase Storage remains the durable private original. Every new attachment gains a chat-sized preview generated during send; synced previews persist in app-private device storage, while opened full-resolution files use a bounded least-recently-used cache. Attachment identity and local paths are stored with the device's last-known chat metadata so airplane mode plus app restart can render the thread. Temporary signed URLs are transport only and are refreshed on reconnect; they are never the local cache key. Missing uncached previews render the neutral media placeholder and never the framework error surface. — locked 2026-08-28 by US-047 / FR-41
27. ✅ **History/media implementation limits:** The client recovery cache is account-scoped, keeps synced attachment previews with cached chat history outside the media LRU, keeps a bounded 50-message preparation window per chat, and limits fallback client work to three concurrent calls. Opened full-resolution files alone use a 20 MiB least-recently-used budget (an oversized single full file is evicted rather than exceeding the cap). Delivery jobs are durable, claimed oldest-message-first, limited to four server jobs in flight, leased for five minutes, retried with bounded backoff, and recovered every minute if a delivery trigger is missed. A cache commit marks matching jobs ready; chat entry hydrates the viewer package first and falls back to the legacy cache during migration rollout. Prepared-package and job uniqueness includes message, viewer, learning language, primary known language, revision, and source version so one variant cannot overwrite another. Preview objects use a separate Supabase Storage path and metadata row; full originals remain unchanged. — revised 2026-09-12 by the offline-history recovery review
28. ✅ **Debug UI workbench:** Keep the review board additive and debug-only at `/dev/workbench`. It uses fixture data, current chat-specific tokens, and local Keep/Merge/Replace/Review notes to audit chat list, profile/settings, chat modes, states, learning-history markers, and similar treatments without mutating production components or user state. — locked 2026-08-29
29. ✅ **Launch invite redesign:** Create and retain one ready invite while the signed-in client is online; after Copy or a chosen native-share target, prepare another unique token. Tokens have no time expiry and are atomically claimed only once a signed-in recipient is known. A claim creates both membership rows with `learning_language = 'en'` and a null `practice_language_selected_at`; selecting any language in the chat stamps that participant’s row. The client preserves only the most recently opened pre-auth token, resumes it after normal email authentication, and reuses an existing pair chat without changing either participant’s learning language. The no-app web path is one static landing template; it never validates or claims tokens. Invite creation is disabled while offline, while a pending valid claim resumes automatically after reconnection. — locked 2026-09-07 by `2026-09-07-invite-flow-redesign-design.md`


30. ✅ **Invite verification repairs:** On Android, invite text uses the native Sharesheet with `ChooserResult` for Copy/selected targets (API 35+) and the legacy selected-component/clipboard-match fallback on older Android; other platforms retain `share_plus`. One account-scoped prepared token survives leaving/reopening the invite page and network changes. The static landing carries the token only in Play’s encoded install referrer; the Android Install Referrer library retrieves it once and the app resolver validates it before auth continuation. Store-install and production-domain verification remain deferred, not claimed by local tests. — locked 2026-09-07 during the owner-authorized invite audit

31. ✅ **Unified learning-language-sheet layout (2026-09-12, revised and owner-accepted 2026-09-14, US-022 / US-027):** The first-time required sheet and later Change language sheet share `2026-09-12-learning-language-sheet-unification-design.md`. Both variants use the handled Settings sheet as the sizing reference: `567 / 932` of the viewport height, capped at 567 logical px plus the bottom safe area; only the list scrolls. Rows are 48 logical px minimum and grow with text scaling; scrollbar proportions derive from visible content rather than a fixed thumb height. Keep system typography per Resolved Decision #6. Both variants share the same flat warm-white surface, `#231208` 30% no-blur scrim, 16 px top corners, 48 px separated rows, selected tint/check, and fixed action. The required variant is undismissable, begins unselected, and commits only through **Start practicing**; the Settings variant has a 32 × 4 px handle, previews changes until **Done**, and may dismiss by backdrop tap or drag. Saving is button-owned; failure restores the same action without error copy. The empty-state card is suppressed while required setup is open.

32. ✅ **Acknowledged invite setup refresh (2026-09-09, US-027):** Track successful selection revisions while refreshing the chat list. Discard an in-flight snapshot started before a confirmed choice and refetch before replacing list/cache state; a completed choice must not reopen mandatory setup. Acknowledged local state remains visible if the follow-up request fails.

33. ✅ **Hindi/Tamil reading script (2026-09-14, US-050 / FR-44):** Store one account-scoped `native | english_letters` preference with a database default of `native`; the single choice applies to Hindi and Tamil and is hidden for other languages. Reuse the existing Translation preferences row and choice-sheet state, exposing contextual native labels without creating per-chat values. Presentation derives a Romanized sentence only when every content token has usable Romanization, otherwise retaining the complete native sentence. Keep native token text alongside visible text for lookup and TTS. Preference changes rebuild loaded current/history presentation only; they do not create translation work, invalidate prepared packages, or alter translation cache identities. Authored and Original text remain authoritative. See `docs/superpowers/specs/2026-09-14-hindi-tamil-reading-script-design.md`.

34. ✅ **Transient feedback behavior (2026-09-14, US-005 / FR-3; revised 2026-09-15, FR-9 / FR-10):** Automatically disappearing Snackbars have no close icon. Passive confirmations use 2.5 seconds; feedback with one action uses 4 seconds and remains available after unrelated taps. Swipe, action, timeout, a replacement Snackbar, or any subsequent route push/pop/replace/remove dismisses it. Interface-language success copy, language name, and Undo label are built from the successfully saved target locale, not the departing route context. Current launch-locale text must fit without clipping or avoidable action stacking; accessibility text may grow naturally. Explicit Save/Apply flows whose result is immediately visible on return, currently Edit Profile and Known Languages, skip redundant success feedback and keep failures where the action happened. Password and confirmed-email success use the shared passive-success presenter: a transparent Snackbar lifecycle shell around a compact `#ECE7E1` pill with a leading 20 px check-circle and localized text, shown only after navigation dismissal for the departing route has completed. Email success additionally requires the same authenticated account's refreshed email to differ from its known baseline; the callback route is navigation-only and cannot create success by itself. Confirmed email changes return to Profile before presenting the acknowledgement. Route-triggered dismissal is deferred until after Navigator build and cannot dismiss newer destination feedback. The broader feedback/offline redesign remains separate. — locked by `2026-09-14-transient-feedback-behavior-design.md`, `2026-09-15-password-success-feedback-design.md`, `2026-09-15-email-change-success-feedback-design.md`, and owner review on 2026-09-15
35. ✅ **Partner safety and visible blocked-chat recovery (2026-09-16, Step 3.6a):** Chats renders the complete conversation list so a blocked conversation remains the recovery surface. Immediate-send pickers filter blocked partners separately. The chat header pushes a full partner-profile page. Its `Report Name` row opens a centered spam confirmation with independent Report and Block outcomes; message long-press alone owns the six-reason content-report sheet. Block requires a localized confirmation dialog, then replaces the blocker’s composer with a persistent `You blocked Name · Unblock` row; no redundant Snackbar or blocked-people settings page is added. Report success uses the factual shared `Report submitted` pill. `is_blocked_in_chat` treats either direction as blocking, so the message-insert policy denies both participants until the blocker deletes the row. Invite claims continue to reuse the canonical pair chat and never remove blocks. — revised by `2026-09-16-partner-profile-reporting-design.md`

36. ✅ **Profile language-settings contract (2026-09-22, US-010 / FR-9 / FR-13):** Keep `profiles.known_languages` as the ordered understood-language set and `profiles.primary_known_language` as the user-facing Translation language. Profile presents understood languages as achievement-like chips without a primary star, followed by one explicit Translation language row. Separate full-screen editors share the same list treatment: understood languages are multi-select; Translation language is single-select across every supported language. Saving a Translation language not already understood appends it to `known_languages` in the same profile update. Saving understood languages without the old Translation language assigns the first remaining selection. Both editors require an actual change before Save, discard drafts on Back, and localize the approved explanations in every launch interface language. See `docs/superpowers/specs/2026-09-22-profile-language-settings-design.md`.

37. ✅ **Versioned onboarding/auth refresh (2026-09-30, US-001…US-005B):** Retain Supabase email, Google, recovery, session, callback, locale, profile, and invite engines while replacing their presentation with the approved native Flutter flow. Store `onboarding_version` plus monotonic `intro | name | language | complete` state on each profile. Advance setup only through authenticated, self-only, idempotent RPCs that atomically confirm the saved display name and merge/set the Translation language without deleting known languages. One asynchronous resolver owns startup and post-auth destinations after session restoration, callback classification, profile state, and invite continuation are ready. A server-owned `onboarding_auth_refresh` flag selects the refreshed resolver or the retained legacy entry; clients can read but cannot mutate it, the production-safe default is off, and debug builds fail open only when the flag cannot be fetched. Owner-requested private tester artifacts may set `BLAB_ONBOARDING_REFRESH_PREVIEW=true` to select the refreshed resolver without fetching or modifying the public rollout flag; ordinary builds omit this define and retain server control. The scoped onboarding/auth visual family uses the approved Paper default states and HTML interaction/motion behavior; it does not globally retheme unrelated app surfaces. Apple remains deferred to iOS. See `docs/superpowers/specs/2026-09-30-onboarding-auth-refresh-design.md`.

38. ✅ **Native Flutter opening animation (2026-10-10, US-052 / FR-46):** Do not add Rive for one fixed launch sequence. Reuse the exact vector paths from the approved orange wordmark and animate them in Flutter inside `OnboardingBootstrapScreen`: hold briefly through the platform splash handoff, reveal `a`, walk in `l`, introduce the first `b`, then duplicate and hop the travelling `b` in an arc over `la` before it lands at the end. Keep the `a` as one unbroken vector; scale its upper form from a planted lower anchor so the top curve and right stroke rise together without seams or detached pieces. As the duplicate `b` passes overhead, `l` and `a` duck together by nine percent and recover on landing. The approved timeline is 2.5 seconds with deliberate holds on `a`, `la`, and `bla`, non-looping and silent. Destination resolution and animation completion form one gate; resolver errors remain recoverable, and a slow resolver holds the final wordmark. `MediaQuery.disableAnimations` renders the completed wordmark and resolves without the decorative delay. The native splash is an icon-free cream surface, including Android 12's mandatory splash handoff via a transparent generated icon. The animation runs when a new Flutter process starts; resuming a still-alive background process preserves its current route and does not replay it.

## Open Decisions

Still need a call. Surface them, don't silently choose.

1. **Word lookup data source:** bundled JSON per language pair (proposed) vs static CDN vs lightweight API
2. **Analytics:** none vs PostHog vs Supabase log queries only
**Resolved by owner, 2026-10-13:** shared Blab visuals/icons on Flutter Material 3, genuine Material navigation and Android-standard transitions/Back. Custom chat capsule and message compositions retain their exact appearance; no platform-specific redesign. Implementation remains subject to screenshot/journey acceptance.

PRD § Open Questions are product questions, distinct from these — keep them separate.

## External References (read before Phase 2.6 E2EE work)

These are *study material*, not code to copy. Signal source is AGPL-3.0 — do not lift code into Blab.

- **Sealed Sender** (Signal blog) — hides "who sent to whom" from the server. Concept is portable to our Supabase-based stack.
  https://signal.org/blog/sealed-sender/
- **Double Ratchet Algorithm** (Signal whitepaper) — the forward-secrecy spec used by Signal, WhatsApp E2EE, Matrix Olm.
  https://signal.org/docs/specifications/doubleratchet/
- **X3DH Key Agreement** (Signal whitepaper) — the initial key-exchange protocol Double Ratchet sits on top of.
  https://signal.org/docs/specifications/x3dh/
- **`libsignal`** — official protocol implementation (Rust core, language bindings). Evaluate for Dart/Flutter bindings before reinventing.
  https://github.com/signalapp/libsignal

### Resolved decision — immediate form correction (2026-09-10)

**Superseded by 2026-09-11 automatic forms below.** Previously: use an account-scoped device-persisted source/target-specific form ledger and one message-bound correction window per chat. The latest explicit form selection, not message sent-time or visibility, owns the window. Settings and inline Change update only the matching active resolution until a new same-chat message. Preserve completed snapshots; retain alternatives from prepared packages. Server preferences remain authoritative for future work. See `docs/superpowers/specs/2026-09-10-form-correction-window-design.md`.

- **2026-09-11 — US-042 state continuity:** MessageArrival retains its child tree with identity transforms when animation/accessibility settings change, preventing chooser-state loss. Closed null snapshots remain unanswered and can resolve passively later; only stored snapshots override prepared alternatives, preserving untouched multi-person markers.

### Resolved decision — Automatic grammatical-form notes (2026-09-11)
US-042 / FR-34 supersedes the chooser and expiring correction window. Retain canonical feminine server text with linked alternatives; add optional suggestedForm and stable author/recipient subjectRole metadata. Audit ownership on every bounded eligible provider attempt, including responses already containing alternatives. Viewer-relative client binding uses the message direction and actual participant names. Explicit preferences win; provisional name suggestions fall back to feminine and are not profile writes. Extend the account/device source-target ledger with one persistent annotated resolution per participant/chat; settings update these targets, while other snapshots stay frozen. Change uses the existing translation-preferences route. Existing snapshots/windows remain readable for compatibility; legacy windows cannot mutate history. Completed snapshots can acquire their first note without changing their text. Copy, Listen and quote previews resolve from the same stored form. See `docs/superpowers/specs/2026-09-11-automatic-grammatical-forms-design.md`.


**2026-10-15 relevance hardening (candidate):** US-042 / FR-34 is unchanged.
Use aligned server/client negative guards for German determiner-only noun
declension, retaining independently audited person nouns/pronouns. Filter old
readable/shared-cache alternatives and prune only invalid local note ownership;
neutral completed results cannot revive old alternatives. Own/private-partner
form saves are account-bound provider work rather than settings-route work,
so leaving Settings cannot interrupt reconciliation. Current-account fencing
prevents late effects entering another user's ledger. No schema migration or
bulk history/cache invalidation. Evidence and remaining approval/rollout gates:
`docs/qa/2026-10-15-german-form-note/README.md`.

### Translation latency and active-work repair (2026-10-13)

Keep candidate-blind source anchoring, independent semantic review models, two agreeing audits out of at most three, strict output contracts, word help, grammatical form handling and ZDR routing unchanged. Run only the first two independent consensus reviews concurrently; invoke the third only when needed. The viewer-scoped read-only `message_translation_work_pending` RPC distinguishes current preparation from failure without exposing jobs or reserving quota. Source hash, historical language revision, account/membership and target/primary-language matching are mandatory; two-minute activity bounds prevent indefinite loading. No UI language-mode redesign.


### Chat interaction batch repair (2026-10-13)

Owner-reported seven cases: Normal must expose authored text while Practice work is pending, without removing Normal’s completed unknown-language exception; mode changes retain a meaningful visible message using reverse-axis global geometry and recover virtualized anchors, with bottom retention taking precedence when already at bottom. Quoted replies navigate within authorized paginated history; both reply entry paths share presented-text selection and keyboard focus. Header/system Back cancel selection/reply before routing to Chats, independent of entry stack. Keyboard dismissal while an active reply’s composer retains focus clears that reply. Notification receipt uses Firebase’s foreground/background handlers for best-effort, bounded, authenticated account-scoped prefetch of originals and prepared variants; tap refresh merges latest messages without invalidating warm or older history, with identity guards across asynchronous work. Removed the fixed 400ms history paint delay. FCM background execution is OS-controlled, so do not promise instant availability after force-stop/offline. Reference: https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages .

### 2026-10-13 translation/motion/highlight repair

Protected literals resolve deterministically without provider work; isolated opaque capital characters skip client language work while real one-letter words remain eligible. Referenced opaque characters must survive both generated text lanes. Same-language corrections require independent semantic consensus against the pre-candidate source anchor before completion. Late-cache recovery is read-only and bounded to six exponentially spaced checks (2–64 seconds by default), source/account scoped and stopped once data resolves. Only MediaQuery.disableAnimations selects reduced motion; accessibleNavigation alone does not. Reply navigation highlights the exact target with the approved full-width background band, one-second hold/350ms fade, leaving bubble colours unchanged and excluding inter-message gap/reaction overflow.

### 2026-10-13 post-v14 interaction review (candidate; acceptance pending)

Owner requests local-first last-tap-wins chat mode, readable incoming authored text while language help prepares, one shared glyph shimmer without message placeholder lines, unread message visibility on entry, bounded capsule feedback, native Android transitions and standard Material FAB size/elevation. Mode persistence is serialized/coalesced and account/chat scoped; failed synchronization retains the local preference and retries on reconnect. Membership refresh cannot overwrite a chosen local mode. Both prepared translation lanes hydrate for the loaded history page without starting generation for the inactive view. The SDK Android predictive-Back/forward-fade implementation is retained; its uncovered background uses the warm app canvas. This explicitly supersedes incoming-placeholder requirements in the older lifecycle decision; initial history/media placeholders are separate and retained. New candidate must pass Android comparison and owner review before main/tester changes.

- **2026-10-14 — Stream activity authority (review-only):** per-message visible reads are canonical Stream metadata, not vendor prefix reads that could mark unseen history. Emoji identifiers are stable ASCII hashes with the exact Unicode glyph retained in vendor custom data; enforce one reaction per participant. Signed reaction events and accepted commands enqueue canonical snapshot recovery. Supabase read/reaction tables are server-only UI indexes for activated chats; no competing writable authority. Typing routes to the canonical chat provider only after membership resolution; privacy OFF closes subscriptions and blocks sends, including late route resolution. Metadata-only translation retries retain verified grammatical subject roles.


### Production setup and local presentation recovery — 14 October 2026

Owner explicitly selects the existing production Supabase project for hosted setup; staging restoration is no longer required. Additive backend installation must preserve existing transport until per-chat migration is verified. Save deployed sources and affected schema definitions before changes; ledger all source migrations transactionally. No paid Stream subscription or main/tester distribution implied.

Offline entry uses an account-bound presentation-only profile snapshot and last verified nonsecret onboarding rollout. Neither cache grants server authorization. Preference mutations and account-data deletion invalidate in-flight generation-bound writers. Canonical read/reaction rendering snapshots persist per account/chat, capped at 2,000 rows per kind. Privacy-OFF reads bypass both subscription and cache. Optimistic reactions are separate from canonical persistence; commands serialize per message, and late results cannot publish into another identity.


### Stream notification-provider boundary — 14 October 2026 ← implementation in progress

Use the existing production Firebase project, with a dedicated FCM-only Stream service identity rather than sharing the legacy multi-purpose Admin SDK identity. Stream retains original-message notification delivery; existing Supabase push remains for unmigrated chats and invite events. Activated Stream learning projections must not enqueue duplicate Supabase chat pushes. Register authenticated devices with two named Firebase configurations: preview-enabled and preview-disabled templates. Per-device provider selection preserves the existing per-device preview preference without placing a private setting in shared messages or merging settings across phones. Both notification templates carry validated chat/message/receiver IDs for local-first navigation and quiet cache refresh. Disable other push event types (edits/reactions) unless the PRD explicitly adds them. Real Android background/cold/offline notification proof is required; configured credentials or vendor acknowledgment alone is not delivery evidence.


### Android Stream background preloading correction — 14 October 2026

A real notification-plus-data receipt displayed the notification, but an offline tap lacked its new message. Stream Android providers therefore use high-priority data-only payloads. The background handler verifies current persisted identity across isolates, fetches authenticated originals/recent history and already-prepared variants, then posts a local OS notification. Preparation is capped at two seconds and never calls AI; unavailable networking or OS background limits retain fallback notification/tap recovery. Display title/body are UI previews only and never authorize or populate message caches. Local notification cold-launch/resumed taps use the same receiver-bound router. Existing Supabase invite/unmigrated-chat pushes remain unchanged. Private preview copies retain the prior localized generic message and hide the sender title. This is implemented but awaiting actual Android red/green preloading proof.

- 2026-10-14 — Notification cache fast path: read the authenticated server-only learning projection first, require the exact notified message ID before committing a snapshot; fall back to canonical Stream HTTP queries when projection has not caught up. Background vendor sessions disable WebSocket and SQLite persistence; UI sessions retain both. No payload preview enters storage. Foreground cache reads reload across isolates and merge newly arrived IDs without resetting timeline/drafts. Imported history will use stable IDs/timestamps/quote references and explicit per-message Blab receipt metadata; vendor import upserts overwrite omitted fields, so complete snapshots and isolated readback checks are mandatory. References: https://getstream.io/chat/docs/node/import/ and stream_chat10.5.0 connection-less client API.

- 2026-10-14 — Deletion captures a private durable vendor-erasure identity before auth cascade and deactivates existing Stream sessions synchronously. A leased worker confirms asynchronous hard deletion of user/messages/two-person conversations/files before marking done. Unknown/failed tasks stay retryable; auth identity still present blocks purge. Partial image uploads wait for both promises to settle, cancel failed upload leases and queue never-committed asset URLs for durable cleanup. Committed ready URLs are protected; new retries wait until cleanup settles. Candidate model routing prefers latency within the existing required-parameters/no-training/ZDR allowlist, retaining provider fallback. No model migration: two isolated text-only calls measured4.7s(gpt-4o-mini) and19.5s(gpt-4.1-mini), neither a population benchmark; cache-hit tokens0 in both. Reference: https://openrouter.ai/docs/guides/routing/provider-selection .


### Owner-approved private media boundary — 14 October 2026

Photos remain in Supabase private Storage; Stream owns canonical message/attachment references, not photo bytes or publicly cacheable URLs. This supersedes the earlier vendor-CDN photo implementation after an actual deleted URL remained downloadable with a14-day cache header. Use server-authorized immutable upload-lease paths, private member-only reads, cacheControl0 and60-second client-only signed URLs. Record durable cleanup ownership before upload; failed/late uploads and auth/chat cascades cannot discard it. Queueing account deletion revokes fresh photo reads and removes completed old client-owned `message-media` files before auth deletion; a leased worker confirms physical absence and retries failures. Existing legacy photos stay in their original private bucket during import; export only allowlisted identity/hash/path metadata, never signed URLs. Unknown cleanup/network failures never count as deletion. No real history cutover, merge or App Tester distribution occurred with this setup.

Migration promotion requires a frozen source, exact complete vendor readback, retained proof hash and matching operator lease. Pre-traffic rollback additionally requires a frozen vendor and unchanged originals/receipt/reaction/media source with no pending work. Benign local learning/view preferences stay in Supabase and are not copied to Stream; they do not invalidate the normalized source fingerprint. New canonical activity refuses this rollback path and requires explicit reconciliation. Historical imports carry the actual legacy edit timestamp so source reconciliation cannot erase it; deleted source text is scrubbed, not replaced by a vendor placeholder.


### Seamless messaging correction — 14 October 2026

Original-message transport remains independent of AI. Normal mode presents full-contrast originals immediately (retaining the existing unknown-language translation rule); only Practice owns shimmer. Replace erase/blank/reveal phases with an atomic readable-result swap; retain scroll deferral and reduced-motion support. Chat routes use zero-duration entry/exit instead of the inherited delayed fade. Process already-leased preparation jobs concurrently within the existing database-wide four-job cap, preserving per-job errors and deterministic outcome order. Provider-model candidates require live quality/timing verification under the existing structured-output and zero-data-retention policy; no new model is promoted yet. Hosted text-first configuration and actual two-client proof remain outstanding.


- Seamless refinement: eliminate chat-list-owned generation entirely; durable server jobs own preparation. Stop visible pending renewal at ten seconds while preserving Realtime/read-only late recovery. Default both delivery flags on with explicit-false rollback. Allocate output tokens by text length and output type (readable/audit/metadata), retaining long-message ceilings; no safety review bypass. Elision boundaries are not literal initials. Local fast-model evaluation is not promotion; funded final coverage remains blocked.

- Funded follow-up: candidate routes OpenRouter generation to google/gemini-3.1-flash-lite and independent review to google/gemini-2.5-flash; explicit model overrides and existing native OpenAI fallback remain. Selected reviewer passed3/3 focused checks (correct Tamil, invented clock-now assertion, O→ears) at615–793ms; GPT4.1mini passed2/3 at1467–2412ms. This small probe is not a general model-quality benchmark. Retain candidate-blind anchoring, two-of-three consensus, output/literal guards and ZDR. Feed resolved source meaning into independent grammatical-form review: noun classes and clock-hour agreement are not participant gender. Prompt word-help as intact written words, including Tamil attached letters; reject letter-bearing tokens mislabeled as punctuation. Keep fragment replies minimal and use explicit context for time contrasts. Final integrated-model/live acceptance remains pending.

- 2026-10-14 21:05 — Exact-source funded acceptance complete:22 sends/44 readable viewer results/44 word-help packages, median2.874s/max6.256s; actual two-client context follow-ups2.918–6.756s.185 backend pass; unchanged Dart894 pass/15 skip. Tamil, fragment/form-review and malformed-optional-form regressions fixed. Actual Android/browser media retained in docs/qa/2026-10-14-seamless-translation. Funding block superseded; owner visual review, hosted rollout and integrated Firebase release still pending.

### 2026-10-14 — Sentence lane integrity and learner grammar

US-015/FR-23: independent sentence audit must attest actual requested output language as well as semantic equivalence. Same-language corrections and unchanged learning text also require known-language lane validation. Lexical edit-distance heuristic cannot veto a correction before candidate-blind meaning consensus; multiple grammar/loanword repairs may be valid. Anchor resolves clear learner grammar to intended minimal meaning, preserves fragments and does not invent consequences. Keep bounded8s budget and literal/name/negation protections. Existing bad production cache is repaired only for specifically diagnosed messages after candidate review, not via an unbounded whole-history invalidation.

Practice mode=none means the learning sentence needs no correction, not that its known-language reveal/audio should disappear. Same-language words remain tappable and long-press uses the existing divider and known-language lane. Learning aids disabled and unsupported-source exceptions remain unchanged. A copied foreign known-language lane is explicitly retranslated before semantic/language approval; reviewer self-report alone was observed to misclassify copied German as English.


### 2026-10-15 — Native route and keyboard ownership

Owner supersedes the earlier instant chat-entry requirement: use the existing Android PredictiveBackPageTransitionsBuilder (FadeForwards fallback450ms) through MaterialPage for pushed chat routes, consistent with new-chat/settings. Keep root/tab pages NoTransitionPage and modal sheets/dialogs on their standard route types; do not replace modal semantics with a full-page slide. Preserve the existing warm fallback color and platform/reduced-motion behavior.

Chats and Profile have no editable fields and must not resize their body/FAB for keyboard insets from a departing route. Set resizeToAvoidBottomInset=false only on those screens; keep keyboard avoidance on chat/forms. App-bar Back dismisses composer focus before popping, without delaying navigation or discarding draft text. Native baseline reproduced keyboard visible over the returning list and an elevated FAB; injected-inset regression failed before the fix.

Pending Practice uses its existing shimmer even after the initial visual deadline, while read-only recovery checks continue. No second Translating status row. Actual terminal errors stop shimmer and preserve the original with Retry. Reduced-motion keeps a stationary original and no animation. These are owner-directed changes, not a new retry/provider budget.

### Owner-selected page motion — 15 October 2026

Supersedes SDK-standard page motion above: pushed pages use PageRouteBuilder, 150ms both ways, cubic ease-out (1-(1-t)^3), fixed positive 48 logical-pixel horizontal travel and matching opacity. Ignore secondary animation so the previous page stays stationary. Back reverses the same curve, not a claim of exact Telegram closing easing or predictive gesture scrubbing. Root tabs, dialogs and bottom sheets retain their distinct behavior. Reduced motion skips decorative travel/fade.

### 2026-10-15 — Narrow standalone OK/okay exception (candidate)

Topic7420, Telegram12768–12770: keep the proposed exception limited to standalone `ok` and `okay`; interpret the repeated `ok` in12770 in the preceding OK/okay discussion. Match case-insensitively and allow surrounding whitespace and ordinary terminal punctuation (`OK!`, `okay?`, `Ok.`). Do not add taxi/hotel/radio/pizza or build an expanding loanword dictionary.

This is not a universal untranslated-content exemption. Accept an unchanged candidate only when appropriate in the actual viewer-selected target language and with the intended meaning. Local-script forms such as Ukrainian `окей` remain language-specific outputs, not an instruction to transliterate arbitrary words. Preserve semantic/language validation and source-conflict guards. Sentences containing these words (`Is that okay?`, `okay, tomorrow`) remain under full translation checks; punctuation and question intent must not be lost. Normal known-language behavior, learning-aids-off, historical language era and primary-known reveal remain unchanged.

Implementation acceptance: cover ok/OK/Okay/okay with punctuation, appropriate unchanged target output, Ukrainian local-script output, rejected wrong-script copies, sentences containing okay, false friends and asymmetric viewer preferences. Implemented in the candidate after independent semantic/language audits; no production deployment changed.

### 2026-10-15 — Executable translation rulebook

`supabase/functions/translate-message/rulebook.ts` owns shared exception configuration, supported-language sets, model/routing defaults, message/source-retry limits and common prompt fragments. `contract.ts` re-exports existing public constants for compatibility. Initial generation, focused retry, semantic audit and readable-text prompts consume this source. `docs/translation-rulebook.md` is generated using `scripts/generate_translation_rulebook.ts`; CI rejects stale output. Preference ownership is an integration contract, not a duplicate preference resolver; the rulebook explicitly indexes remaining implementation owners (schemas, scheduling, orchestration). PRD remains product authority.
### 2026-10-15 — Open timeline reconciliation (candidate)

US-031: independent chat-list updates are a missing-message hint, never message content. When that chat's latest ID is absent, fetch through its authoritative ChatService transport and merge without losing older pages. Retry a transient read with capped exponential delays (200/400/800/1600/3200ms), coalesce triggers, stop after catch-up, and cancel scheduled work on provider disposal. Event-enrichment/stream errors also request reconciliation instead of silently waiting for another message. Do not generate translations, change preferences, or copy list preview text into a bubble. This closes proven lost-event/enrichment gaps; it does not diagnose the phone's precise network failure or guarantee delivery when both independent feeds fail.

### 2026-10-15 — Pending-display liveness safeguards (candidate)

Start the translation loading watchdog before initial cache I/O so stalled I/O cannot prevent read-only recovery. Ready-content scroll deferral is bounded at 750ms and cancelled on pending/reset/disposal; ScrollEnd still resolves immediately. No changes to language targets, historical revision, source identity, semantic acceptance or AI initiation. Exact 22-call trace analysis is in docs/qa/2026-10-15-stuck-shimmer/README.md; call-reduction work remains separate from these client guards.

### 2026-10-15 — Owner-approved single-call architecture (candidate)

Supersedes earlier active multi-audit/source-anchor/hedged generation guidance: normal durable message preparation claims all eligible viewer jobs as one message/source batch, generates one structured result keyed by viewer and commits atomically under per-job lease fences. Compact rules are generated from rulebook.ts; context capped3 entries/1800 UTF-8 bytes per viewer. Existing RPC preference/history/source rules are unchanged. No independent model review, source-analysis or word-help calls; code validates structure, literal preservation and metadata. Retry actual failures only through durable scheduler (max4, Retry-After respected). Manual/legacy direct requests remain one call for their requested viewer. Protected literals require no model. The retained v11 contract tag denotes compatible stored result schema, not a requirement to run the retired source-anchor pipeline.

This explicitly accepts the bundled-output trade-off: word metadata increases output size and an invalid bundle can require a bounded retry; an independent AI second opinion is no longer present. Deterministic form normalization uses only supplied complete alternatives and token metadata. Source identity and author/recipient mapping remain mandatory.

Live chat resubscribes after stream failure, schedules independent10-second reconciliation while observed/online, bounds history/cache reads6 seconds, and preserves merged historical pages. Translation watchdog starts before initial I/O; scroll-end deferral bounded750ms. Evidence docs/qa/2026-10-15-single-call-reliable-chat. Release remains subject to owner visual/workflow review.

### Composer emoji input — 15 October 2026

Reuse the installed emoji_picker_flutter engine in a nonmodal inline panel, with the approved tintable SVG toggle assets. Chat owns panel visibility so app-bar/system Back close it before reply/navigation. Composer insertion and backspace edit the existing controller at its selection and enforce the existing grapheme limit; do not pass the controller to the picker (which bypasses our input formatters/limit). No translation, cache, account preferences or backend changes. Interface locale owns picker search and action labels. Owner authorized feature work after icon approval in Telegram12800; implementation review is separate.

Height revision12807/12809: Chat owns bottom avoidance (Scaffold does not also resize). Composer reserves max(active IME inset, measured panel obstruction, navigation inset). The grid excludes the bottom navigation inset; input padding is shared, with no extra panel gap. Keep measured obstruction during the350ms input-connection handoff. Search explicitly reports its state and reserves its compact result panel above the search IME. Regression measures identical composer geometry before, during and after an IME/panel handoff.

Handoff correction12818: retain the actual disabled picker artwork while returning to the IME, not an empty reserved SizedBox. Remove the retained artwork only after the IME inset covers the measured obstruction (next frame); a2s no-IME fallback releases it if software input never appears. Icon/input mode changes immediately so the text connection can attach normally. Frame-by-frame native review is required; stable-state geometry and sparse video contact sheets were insufficient proof.

Jump-to-latest request12824: listener-driven bottom-center overlay inside the timeline bounds, outside the scroll contents. Reuse arrow-up SVG rotated180 degrees, warm44px circular control. Reverse-list offset0 is latest; show above200dp, animateTo0 over300ms easeOutCubic (jump for reduced motion). Does not mutate messages, read receipts, draft, focus or auto-scroll ownership.


### Compact one-call wire format — 15 October 2026

Owner12931 authorizes compact dynamically resolved language requests and tester delivery. The provider wire format separates unique language/tone/eligible-context sentences from learning-sentence/known-language word help. A stable schema and canonical fixed rule prefix precede deterministic sorted settings; sender/recipient and bounded context are data, not repeated per viewer. Sender/recipient form ownership is mapped back into existing viewer-relative storage by code. Existing source/revision fences, atomic batch persistence, historical cache contract, Normal/Practice and aids-off decisions remain unchanged. Runtime prompt caching is provider implicit best-effort; no padding, explicit content-storage cache or privacy-policy weakening. Record measured cached tokens, not inferred savings.

### 2026-10-15 — FR-47 separate testing namespace (candidate)

BLAB_APP_CHANNEL=test uses package blab.nastia.ez.test, blab-test scheme, /i-test/ links and staging-only hosted configuration. Public defaults remain package blab.nastia.ez, blab scheme and /i/. Dart and Android reject test→production; public→staging is also rejected. Separate Supabase projects isolate auth signatures, user IDs, invites, messages and storage; neither a client parameter nor binary label grants database rights. Prefix test- is server-minted, namespace-checked on claim and retained through auth continuation/referrers; URL-path edits cannot convert invite authority.

app_distribution_policy defaults public so the migration alone changes no existing access. Only trusted operators can configure a test deployment, enable/expire it and register test_app_members by verified account UUID. is_account_active and member/read RLS enforce access in old clients too. The test-only shell verifies backend channel and access on entry/resume and every15s; failed checks block, rather than preserve an indefinite offline grant. Public app has no test gate. This is not hardware attestation or remote erasure; installed app content can have already been seen. No public history transfer.

Hosted staging provisioning, distinct Firebase app/OAuth registration, signed app-links verification and actual deployment require separate release evidence after owner reviews the candidate. No existing production accounts are enrolled automatically.

### 2026-10-15 — Owner visual parity revision

Owner rejected test banner and extra invite copy after actual screenshot review. Keep separate package/backend and `/i-test/test-…` routing, but use public app name/icon, invite title/card/helper/share text and unwrapped active/signed-out child layout. The access gate adds no permanent chrome or padding; only pending/denied/error states intercept access. Existing mismatch errors remain to enforce the requested boundary. Previously sent screenshots12971–12974 are superseded for visual approval. No hosted change.

### 2026-10-15 — Invited test emails

Owner requested preapproval of named testers before signup. Operator-only `test_app_invited_emails` grants access only to a matching verified auth email; explicit UUID membership denial/expiry takes precedence. Global test disable/expiry and account enforcement remain unchanged. Public policy remains unchanged. No invitation URL or client flag grants access. This extends the UUID-only enrollment above.

## Resolved — reusable personal invitations, 16 October 2026

Owner replaces decisions13/29/30 single-use/automatic rotation. `create_invite()` returns the current reusable token, including for older clients calling it after share. `regenerate_invite(current_token)` atomically revokes all owner links; owner advisory lock serializes creation, regeneration and claims. Repeated regeneration with a revoked token returns current token, making lost-response retries safe. Claim retains canonical pair uniqueness, membership preferences and blocks. Existing unclaimed tokens become reusable; old claimed tokens are never reactivated. Server-minted128-bit random IDs preserve namespace. UI uses inline Regenerate, localized explanation and authoritative refresh after uncertain network outcome; no public name slug needed.


## Resolved — chat lifecycle, 16 October 2026

Terminal `chats.left_at/left_by` and both memberships' `chat_left_at` drive existing realtime watchers. Authenticated `leave_chat` and invite claim use the same pair advisory lock; active-pair partial uniqueness permits retained closed histories plus one new conversation. New legacy writes and Stream command/media reservations take a shared chat-row lock and reject terminal chats, while leave serializes with an exclusive row lock. Preauthorized vendor work may reconcile history, never reopen messaging. Personal `delete_chat` sets only that viewer's hidden timestamp and history cutoff; SELECT RLS and client rendering enforce the cutoff. Only a genuinely newer incoming message unhides the membership. Reinvite after a personal clear closes the former pair and creates a fresh one without deleting partner history. No translation or block policy is changed. Screenshot review, native verification and owner manual acceptance remain release gates.

## Connection-notice removal · 2026-10-19

Owner removed global Connecting/No connection banners (US-031). Keep the shared notice slot zero-height and silent; retain connectivity providers, queue/reconnect, access authorization/error recovery, and per-message feedback unchanged. The unmerged update-notice candidate remains separate and must retain its action when integrated.


## Resolved — BLA-21 · 20 October 2026

Thread an optional quick-heart callback from ChatScreen through timeline/row/bubble to MessageInteractionTarget's double-tap recognizer. Keep badge tap opening details. Reuse existing reaction notifier and server commands; rollback on failure. No translation pipeline or preference changes.


### BLA-21 shared reaction pill · owner14372

One capsule renders distinct aggregated emojis and sum(count) on the right. Server permits one reaction per person/message. Retain32px visible/44px touch height, existing colors and Practice shadow. Anchor incoming left/outgoing right at lower outer bubble corner so variable-width pill grows inward without clipping short messages. No state, server or preference changes.


## Resolved — BLA-16 · 20 October 2026

Leave _status unchanged on test-access transport failure and on resume. Owner correction (20 October): ended status must not replace the chat with a session-ended screen; retain chat/draft through expiry and offline resume. Not-approved/configuration mismatch remain blocking. Server-side authorization remains authoritative for commands. On restored active access, invalidate chatListProvider after the reveal frame to avoid invalidating paused dependent subscriptions. No authentication, RLS, queue storage, translation or production changes.

## Reviewed animation batch ·20 October2026

- Logo:450ms initial a/handoff hold,950ms motion,1.40s total. l joins at35% of motion; exact letter paths unchanged.
- Onboarding:13.75s playback maps onto existing7.75s phase motion, extending only reading phases. Conversation pointer down stops controller immediately; last release/cancel resumes current phase. Continue and reduced-motion final state remain usable; no translation or auth changes.

## BLA-14 conversation candidate · 19 October 2026

Reuse the established PostgreSQL text-message transport and ChatScreen; do not
enable Stream group transport implicitly. Snapshot non-sender group recipients
when a message is accepted, serialized with membership by the chat-row lock.
Group aggregate read RPC exposes only the sender's fully-read message IDs,
never partial reader identities. Snapshot remains unchanged after joins; no
other recipients means no automatic read status. Client privacy OFF continues
to suppress read transport/display. Group history SELECT is constrained by the
viewer's join boundary. Group messages never qualify for two-person shared
correction marks, including two-member groups; legacy shared learning rows are
author-only while per-viewer private variants retain their established keys.
No new translation targets, policies, prompts or AI-provider work are introduced.
This is local candidate engineering, not acceptance of all group journeys.

### BLA-14 recovery · 20 October 2026

Group information uses the existing native shared controls, supplied SVG icons
and page motion. Member menus anchor to their tapped row, not a fixed screen
coordinate. Rename reopens from the refreshed chat identity and preserves input
on failure. Required language selection receives an explicit request-preview
presentation (View message/help), independent of the unchanged translation
preference mapping documented in the conversation QA record. Viewing does not
call acceptance; the database suppresses all pending-request receipts.
The disposable groups backend was rebuilt from all 108 migration files, fixing
the retained manual-application/ledger drift in migrations 5 and 6.

### BLA-14 owner notice · approved slice 14432

Reuse the isolated dependent groups worktree: the group screen/authority
contracts are still uncommitted and absent from main. Preserve that work rather
than copying a dirty checkout into another branch. Reconcile current main before
integration. The approved p-6-0 Paper alert uses showBlabDialog and
BlabConfirmationDialog with the exact warm 28px surface,40px horizontal inset,
20/15/14px type and48px dismiss target. Interface Language alone owns its four
localized strings. No translation, database mutation or automatic owner selection
is performed by opening/dismissing the notice. The notice is shown only to the
current owner with other members; regular/sole-member departure is a separate
unfinished group lifecycle slice, never the direct-chat leave RPC.

### BLA-14 completion ·14489 ·20 October

Group notification state is per chat_members row and per account, persisted via
an active-membership RPC. Mute is checked when queueing and when claiming queued
group pushes; it does not alter other participants or direct-chat behavior.
Notifications use the existing warm row and a two-choice popup, not a new screen.
Shared photos listen to real message/attachment changes, including initial and
reconnect resync. Thumbnails keep the Paper78px preview/10px radius variant;
chat-photo defaults remain12px. The storage history policy must allow the active
uploader's own path before attachment metadata exists (storage upsert SELECT),
without opening orphaned objects or pre-join attachments to other members.
Storage and Realtime are enabled only in the isolated groups backend. No hosted
changes. Native settings/media evidence uses real upload/download/readback and
live subscriptions, not simulated image or synchronization responses.

Web attachment selection uses image_picker's browser file chooser and XFile
bytes; native retains the established photo_manager sheet. Browser cancellation
must leave the chat unchanged and allow immediate reselection. Roster now listens
to RLS-scoped chat_members snapshots and refetches the display-only roster RPC
after changes, including initial/reconnect refresh. No permission widening.

Live-learning acceptance is separate from private-request UI/privacy proof.
Configured application provider returned HTTP402 payment required in local direct
translation testing; no successful asymmetric-language or automatic-worker proof
is claimed. Device notification dispatch likewise remains unverified without the
local FCM credential. Lifecycle history semantics remain a required open choice.

Browser media preferences use a shared2Mi-character full/preview cache budget
across accounts, not the native20MB full-file LRU. Trim legacy media when loading
chats/history and serialize media saves; never evict auth, drafts/unsent messages
or text metadata. Originals remain server-backed; oversized media caching is
best-effort. Group information/photo/notification reads have an8s timeout and
bounded requests. Request14530 supersedes the full-page Retry fallback: group
identity always renders; saved account/chat-scoped roster, photo manifest and
own mute setting survive transient failures. Recovery retries every10s only
after failure, with source-table/reconnect refreshes and disposal cancellation.
Authoritative42501 clears cached group information rather than granting stale
access. First-load failures keep known metadata, not invented members/photos.
Channel names use monotonic sequence IDs; timestamp-only names can collide for
simultaneous browser observers. Actual membership watcher is RLS-filtered CDC,
not a table stream whose initial REST failure can permanently end observation.


### Group lifecycle and AI boundary —14578, in progress

Keep the existing dependent group worktree and isolated Blab_Groups_20261019 runtime; do not copy dirty contracts into main. Lifecycle serializes against the group row. Departure deletes active membership and private prepared/readable/job/attempt bindings, retaining canonical originals and immutable read-recipient snapshots. A separate private departure record denies removed-user tokens created before removal; rotation creates a genuinely newer token. Last-member exit closes the group and revokes invitations. Join stamps joined_at using clock_timestamp; clients cannot change it.

Original history RLS permits current group members, independently of AI eligibility. Group AI requires message created_at >= current membership joined_at; initial language backfill is filtered before job insertion, learning-era resolution and private package/readable access/write paths enforce the same cutoff. Client Chat.aiStartedAt is persisted account-scoped and gates rendering, prefetched translations, quotes and selected-message actions. Fresh joins clear saved chat learning snapshots; authoritative departure/rejoin list refresh clears stale snapshots. Direct-chat historical language behavior remains unchanged.

Cost batching redesign is still pending; see docs/specs/2026-10-20-group-ai-cost-and-membership.md. Local lifecycle SQL and client cached-translation regression pass; not yet whole-feature acceptance.


### Group completion implementation checkpoint14578

The previously pending cost redesign is now local source: message-level leases, exact output-contract deduplication, service-only source/contract-keyed artifacts and private author/recipient result bindings. At most four distinct contracts per token-bounded generation; at most four generations before yielding unprocessed viewers without decrementing their failure allowance. Durable periodic dispatch resumes deferred work. Preparation and independent private commits use bounded100-viewer RPC arrays with per-viewer completion isolation. Interactive group misses defer to that durable owner, not a competing provider call. Existing direct-chat pipeline stays separate.

Canonical paginated group_joined rows are server-only, localized at display time, excluded from AI/unread/ordinary pushes/human previews, and do not impersonate a group author. User-private departure hints permit revocation delivery even after content RLS denies access. Original-only rendering and clearing both disk and in-memory learning/outbox state fence a new membership epoch; disposed language fetches cannot overwrite its cache.

Account-erasure fallback is distinct from ordinary Leave: transfer to a remaining member or delete an empty group so a permanent account deletion does not fail the owner FK or erase remaining members' group. Queued push claims must match current membership timing. These last SQL safeguards009/010 are authored, not applied/tested while Docker is blocked. Final native source must be rebuilt; earlier packaged QA APK is superseded after the memory-boundary fix. See completion-14578 QA for gates; no acceptance/release claim.

## Group conversation approved composition ·21 October2026

Implement14898 as group-only variants of shared chat components rather than a second message-rendering pipeline. Resolve membership epoch, historical Learning Language, Primary Known Language, mode, aid toggle, tone/form and reading script unchanged before presentation. Interface Language alone owns the header caption/composer labels. Incoming metadata/spacing/name/avatars change, never cached output eligibility or AI scheduling. Accessible title measurement can grow the identity row; the utility row stacks at large text. Retain platform font rendering.32px initials avatars use the existing warm palette, group-local stable name hashing with plum Alice fixture; do not add photo upload/product scope. Existing local groups backend remains owned by the preserved BLA14 worktree; this UI worktree is read-only consumer, with no function/background dispatch enabled.


## Final group refinements ·21 October2026

Latest owner screenshot feedback supersedes the earlier two-row Paper header: remove the practicing-language caption and keep identity, mode toggle and menu in one toolbar row. Long titles ellipsize; enlarged text/narrow screens retain a compact icon control with full mode semantics and44px activation height. Group-only;1:1 remains unchanged. Hide the complete Shared media section after a confirmed empty result; retain loading/retry and show it once a photo exists.

Verified on Android5560 and390×867 Web: native conversation and information journeys pass; inspected replacements delivered15001 and15003. Full client1,026 passed/16 environment skips; analysis clean. Fresh122 migrations/15 SQL suites and211 worker checks passed previously on the same backend source. Main group integration68e22be pushed; final refinement integration/test32 delivery pending. Staging17 migrations and2 modified functions promoted without production changes. No new AI generation for these refinements.


## Group in-app invitations ·15062 ·21 October2026

New group_invite_friends/send_group_invitations RPCs validate current membership, accepted direct connections, mutual block boundaries and current nonmembers on server. Individual invites reuse private pending inbox; no translation jobs. Refresh on private RLS-filtered realtime events; named invitations follow owner link rotation. Dedicated current-main worktree7e7a5a7; no shared/hosted database mutation or release authorized for this new visual slice.

## Reviewed native invitation sender flow ·22 October2026 /15272

Paper V15 p-B-0 is the sender UI source, including15235/15241 reductions.
InviteLinkPanel composes native Material, TextButton.icon and FilledButton.icon;
personal/group pages reuse it without hero art or helper copy. Existing Blab
selection rows compose native ListTile with a plain check, and selection count
includes1. Reset uses PopupMenuButton and AlertDialog, preserves reusable-link
and named-invitation authority. Copy writes the full HTTPS URL; sharing invokes
the platform sheet directly. Create group navigates to its chat; invitations
remain optional. The friend picker scrolls as one body while Send remains fixed
so320px/200% translations remain usable. Recipient screens/learning policy unchanged.
Candidate is isolated, based on current main d983a6a; review precedes integration.

Sender correction15313: production group route and GroupInfoScreen now instantiate
GroupInviteLinkScreen directly. GroupInviteScreen remains unreachable from app
entry points; earlier candidate picker/backend source is preserved, not a new
release requirement. Preserve already-issued invitation/recipient compatibility.

Reset confirmations reuse BlabConfirmationDialog with explicit chatSurface and
the existing rounded28 border variant, avoiding the pink default without changing
other dialogs. Optional scrollable flag defaultsfalse; only these callers optin.


## Approved Paper V16 invitation picker ·15498 ·22 October2026

Supersedes direct-link correction15313 and all later exploratory sender references.
Paper p-C-0 states6FT-0/6GW-0/6IL-0/6JM-0 are canonical. Group details Invite
friends and /group/:id/invite restore the existing Blab-friend picker. No global
user discovery. Top-right Search replaces the title with a366x56px neutral
#EEE8DF radius28 field,12px inset, native Back and Clear inside48px targets;
gray Search friends placeholder, no username/phone lookup. Preserve selections
through filtering/Clear/Back and external-link navigation. Invite outside Blab /
Share a link stays above people. No section/footer dividers or Friends on Blab
heading; list64px rows,8px gaps; pinned52px Send invite / Send invites(count).
0 disables Send; private invitations never auto-join. Search/keyboard Back
consumes search before leaving the picker; leaving hides keyboard. Localization
uses Interface Language only; no learning-language/translation pipeline changes.
Implementation authorized, actual native visual/journey acceptance still pending.
No merge/main integration, hosted migration or release authorization.


## Integration authorization · 22 October 2026 ·15553
Nastia reviewed the actual Android packet15539–15543 and explicitly requested
“check for conflicts, commit and merge to main”. This supersedes the pending
visual/integration authorization above for this invitation slice only. No hosted
migration, service deployment, update notice or tester distribution is authorized.
Fetched origin/main617639c equals the reviewed candidate base: no textual merge
conflict or intervening main changes. All reviewed source hashes match the final
V16 manifest. Historical exploratory tests/captures remain in the retained checkout;
only final V16 native acceptance and its QA entry are promoted. Manual physical
phone/iOS/hosted acceptance remains open; the launch tracker stays unchecked.

## Production iOS communication notification contract ·16208 ·26 October2026

Release-enabled Runner bridge and NotificationService share a fail-closed app-group account
snapshot/epoch with the approved NotificationContent renderer. Privacy/identity transitions
rotate epoch and purge delivered/pending notifications and Siri donations. No credentials or
message history in app groups. Versioned per-token RPC and generic-alert/mutable-content APNs
contract are specified in docs/qa/2026-10-26-ios-production/README.md; backend/main/deploy remain
parent-owned. Existing legacy iOS and Android capabilities are not silently upgraded. Approved
40–45 appearance preserved; source tests do not replace signed physical-device APNs acceptance.

### BLA-13 ·29 October2026
- Reuse the existing language registry, translation contract and system TTS engine; explicit da-DK/fi-FI/ko-KR/mr-IN/pl-PL mappings do not guarantee installed voices. Add mr to the shared reading-script eligibility set and use Devanagari presentation; no schema change to that preference.
- Forward-only language migration expands the exact old learning allowlist in current and renamed compatibility functions while preserving signatures, privileges, RLS and cache rows. Four interface locales remain unchanged. Existing translation keys include language, so no invalidation of old accepted sentences is required.
