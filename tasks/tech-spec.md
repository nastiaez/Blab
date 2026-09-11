# Tech Spec: Blab

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
| iOS      | 2     | iOS 14      | Matches Flutter's current minimum |

Rationale: the PRD calls for an "iOS-native feel" but we ship Android first. We keep the iOS look across both platforms (sunset-orange brand on cream, rounded corners, bottom sheets, system fonts) rather than adapting to Material on Android. This is a product choice from `prd-blab.md` § Design Principles, not a Flutter constraint.

---

## Project Layout

```
lib/
  main.dart                  // app entry, theme, root router
  app/
    router.dart              // route definitions (one route per PRD flow)
    theme.dart               // colors, typography, radii — pulled from prototype.html
  features/
    auth/                    // Flow 1 (US-001…US-005)
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
| Email + password auth, Apple SSO, Google SSO, password reset | **Supabase Auth** (`supabase_flutter` package) |
| Persistent storage (users, chats, messages, invite links) | **Supabase Postgres** with Row-Level Security (RLS) |
| Real-time chat transport (US-015, US-016) | **Supabase Realtime** — Postgres change streams + Broadcast channels for typing/presence (if added later) |
| Avatar uploads (US-011) | **Supabase Storage** |
| Invite link valid until one successful claim, with no time expiry (FR-4) | Postgres table + RLS policy + edge function for token mint/validate |
| Push notifications (US-038, FR-29) | **FCM via Supabase Edge Function** trigger (Supabase has no native push) |

Conventions:
- One Supabase project per environment: `dev`, `staging`, `prod`.
- All tables get RLS on day one. No service-role keys shipped in the app — Flutter uses anon key only.
- Migrations live under `supabase/migrations/` (Supabase CLI). PR-reviewed; never edit prod via dashboard.
- Generate Dart types from the Postgres schema with `supabase gen types` → checked in under `lib/shared/models/db/`.

**Out of scope for backend:** language matching/discovery, payments, voice/video, group chats, and AI-generated conversation partners. Message translation is implemented through the authenticated `translate-message` Edge Function and OpenRouter.

Message translation and word metadata come from the authenticated translation service and are cached by message, learning language, and primary known language. The popup itself makes no network or model request: it reads the cached per-word gloss and Latin-script transliteration, while audio stays on-device TTS (FR-11, FR-24, FR-33).

---

## Design Fidelity

The prototype (`prototype.html`) is the visual + interaction reference. Translation rules:

| Prototype | Flutter |
|-----------|---------|
| `#5B4FE8` purple | `ThemeData.colorScheme.primary` |
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
- Launch interface locales = English (`en`), Ukrainian (`uk`), German (`de`), and Spanish (`es`); English is the synchronous default and invalid/missing-value fallback
- The guest preference is device-local; signed-in preferences are cached under an account-scoped key and persisted through a self-only profile RPC
- **Interface language** (chrome strings) is distinct from **learning language** (chat content). Don't conflate them.
- Learning-aid cache identity is currently `(message_id, target_lang, interface_lang)`, where the legacy `interface_lang` storage field carries the reader's primary known language for message output. Authored text remains authoritative in `messages.body`; each row stores learning-language output, primary-known-language output, detected source, tokens, and correction analysis. App chrome and explanatory copy still use the real interface locale
- Retryable learning-aid failures remain client-local `AsyncError` entries. Manual Retry clears only the failed `(message_id, target_lang, primary_known_lang)` variant before re-running the server-authoritative cache/function flow
- Tapping a learning word retains its definition gesture; tapping empty bubble padding does nothing. Long press opens the launch reaction/action treatment. Normal may reveal exact authorized `messages.body` through Original; Practice uses the cached primary-known-language line and Listen instead

---

## CI / Release

Not yet set up. When added:
- GitHub Actions: `flutter analyze`, `flutter test`, `flutter build apk` on PRs
- Internal track on Google Play for dogfooding before public release

---

## Crash Reporting + Observability

**Decision: Sentry** (`sentry_flutter`). Locked 2026-05-25.

- Initialize in `main.dart` before `runApp`; wrap with `SentryFlutter.init` runner.
- Capture: unhandled errors, Flutter framework errors, Dart isolate errors, network 5xx, performance traces for cold-start and chat-view first-paint.
- DSN per environment (dev / staging / prod) via build-time `--dart-define`.
- PII: scrub email + message bodies before send. User id only.
- Source maps / debug symbols uploaded on release builds via Sentry CLI step in CI.

## Resolved Decisions (log)

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
14. ✅ **Interface-language behavior:** English, Ukrainian, German, and Spanish are the launch interface locales, with English default/fallback and account-scoped persistence. Interface language controls chrome, word-definition/explanation copy, and correction explanations; it is not a message-translation target. The reader's primary known language controls Normal's unknown-language translation and Practice's temporary second line. Authored text remains authoritative and is available through Normal's Original action whenever displayed text differs. — revised 2026-08-24 by the launch long-press contract
15. ✅ **Log-out UX:** Confirm dialog before sign out ("Log out?" / Cancel + Log out). Signal pattern. — locked 2026-05-28
16. ✅ **Palette + type tokens (final v1 swap):** Brand `#D4694A` (press `#BB573B`, soft `#F3DAD0`). App canvas cream `#EFEBE2`. White surface for sheets + (per-screen) status-bar safe area. Ink `#1F3340`, stone `#9A9490`, line `#E4DCCC`. Input focus border `#E19680` (softer than brand to avoid alarm). Selected-row tint `#FAF1EC`. Avatars = deterministic warm swatch from `[#46281C, #917869, #BC6C4E, #788C73, #AF787D, #5F3C4B]` keyed by name; the former palette is retired and gradients remain excluded. Links use brand; chat receipt icons use the gray single/double-check contract in Decision #22. System fonts only (Roboto on Android, SF Pro on iOS — same as #6). The approved chat-only surface, mode-switch, and message-bubble exception is defined in `docs/superpowers/specs/2026-08-23-chat-practice-mode-ui-refresh-design.md`. — revised 2026-08-24
17. ⛔ **Portfolio-mode live translation backend (retired):** The historical public `translate-portfolio` demo endpoint was removed with L-13 after portfolio mode left the app. It must not be deployed for launch. Historical design remains in `docs/superpowers/specs/2026-06-02-portfolio-live-translate-design.md`. — retired 2026-07-17
18. ✅ **Launch translation security:** The Flutter client submits only a message ID to the JWT-verified `translate-message` Edge Function. Postgres derives the authorized source body and caller's learning language, enforces active membership plus the viewer's assigned language revision, and atomically reserves the approved per-account quota only on a cache miss. Only the server can write prepared translation packages, and writes compare both a SHA-256 source hash and viewer-language revision to reject edit or preference races. OpenRouter requests use `openai/gpt-4o-mini` through any eligible endpoint with `zdr=true`, `data_collection=deny`, fallback routing enabled, and required parameter support. The live ZDR catalog currently exposes this model through Azure, but Blab no longer hard-codes Azure as the only provider. — revised 2026-08-28 by US-044 / US-046
19. ✅ **Same-language writing correction:** The learning-aid contract returns exactly one mode: `translation` when source differs from the learning target, `correction` for a clear mistake in that target, or `none` for correct writing. Matching learning/interface locales reuse one cache row. The author alone sees correction marks and a localized explanation; recipients see the clean corrected result. Ambiguous author corrections are labeled as possible and the provider must make the smallest defensible change without inventing missing meaning. — revised 2026-07-18 by owner approval during L-15
20. ✅ **Gallery attach picker:** custom in-app photo grid (`photo_manager`) replaces the Android system photo picker for the chat gallery-attach flow, matching WhatsApp/Telegram rather than the OS-branded picker sheet. Camera capture still goes through `image_picker`. Requires `READ_MEDIA_IMAGES` + `READ_MEDIA_VISUAL_USER_SELECTED` (Android 14+ partial-access) permissions declared in the manifest; a denied/partial state shows an in-app prompt with a link to system settings rather than failing silently. — locked 2026-08-06
21. ✅ **Grammatical-form memory:** Store only `not set | feminine | masculine`, with no confidence score or usage history. The user’s own value is account-scoped and authoritative; a partner value is a private one-to-one fallback and must never update the partner’s profile. Formality remains a separate per-chat value. Generated translations may return linked alternative segments plus the affected participant so the client can resolve all agreement changes together. — locked 2026-08-14 by US-042 / FR-34 / FR-35
22. ✅ **Launch message-action contract:** Follow `docs/superpowers/specs/2026-08-24-chat-ui-refresh-simple-long-press-design.md`. Word tap and message long press are separate; empty padding has no tap action. Copy/Reply resolve from the mode’s primary displayed text, while Edit always starts from authoritative authored text. Emoji/whitespace-only edits may reuse language-help output; any changed letter, number, or punctuation invalidates it. Receipt presentation is clock → single gray check → double gray check, with no distinct device-delivered visual. Confirmed Delete removes for both with no tombstone/Undo. Read-receipt OFF must suppress the outbound event rather than store a hidden read. — locked 2026-08-24
23. ✅ **Unresolved grammatical-form audit:** For a form-relevant target language, a generated translation with no alternatives cannot be accepted solely because the general translator returned `null`. While either participant’s form is `not set`, a focused server-side agreement audit must confirm that the sentence is naturally form-neutral or provide the exact shared prefix/suffix, the shortest complete feminine and masculine changing fragments, and the affected participant. A confirmed required choice must be present in the final cached translation; otherwise the request fails instead of silently storing one form. — locked 2026-08-24 by the on-device Ukrainian regression
24. ✅ **Message lifecycle motion:** Keep translation data in the existing locale-scoped Riverpod cache and render the lifecycle as a local, message-owned visual state machine. A delivered outgoing Practice message uses the 180/350 ms speed branches, a glyph-only shader wave, and sequential 120 ms clear → 150 ms measured empty resize → ≤220 ms land phases. Incoming language help is held until resolved, cached/off-screen results render final without replay, a finger scroll defers only the visible resolve, reduced motion swaps statically, and the client performs one quiet retry within one shared 10-second deadline. — locked 2026-08-24 by US-043 / FR-36
25. ✅ **Prepared viewer packages + private language timeline:** A durable server-side job is created transactionally after message delivery for each participant. The worker derives that viewer's learning language, primary known language, form/tone preferences, source version, and private learning-language revision, then persists one viewer-specific package containing both Practice output and Normal fallback before announcing readiness. Completion uses compare-and-set on `(message, viewer, source version, language revision)`; a result can activate only in the message era it was prepared for. Work already attached to an older message finishes in that older language above the next private marker, while messages delivered after the marker use the new language. The original message is stored once; frequent switching adds only small revision events and does not duplicate the chat. Client-on-open remains a recovery path, not the primary trigger. — revised 2026-08-29 by the device-reviewed language-switch sequence
26. ✅ **Offline chat-media cache:** Supabase Storage remains the durable private original. Every new attachment gains a chat-sized preview generated during send; synced previews persist in app-private device storage, while opened full-resolution files use a bounded least-recently-used cache. Attachment identity and local paths are stored with the device's last-known chat metadata so airplane mode plus app restart can render the thread. Temporary signed URLs are transport only and are refreshed on reconnect; they are never the local cache key. Missing uncached previews render the neutral media placeholder and never the framework error surface. — locked 2026-08-28 by US-047 / FR-41
27. ✅ **History/media implementation limits:** The client recovery cache is account-scoped, keeps a bounded 50-message preparation window per chat, limits fallback client work to three concurrent calls, and evicts media with a 20 MiB least-recently-used budget shared by preview and opened full-resolution bytes (an oversized single file is evicted rather than exceeding the cap). Delivery jobs are durable, claimed oldest-message-first, limited to four server jobs in flight, leased for five minutes, retried with bounded backoff, and recovered every minute if a delivery trigger is missed. A cache commit marks matching jobs ready; chat entry hydrates the viewer package first and falls back to the legacy cache during migration rollout. Prepared-package and job uniqueness includes message, viewer, learning language, primary known language, revision, and source version so one variant cannot overwrite another. Preview objects use a separate Supabase Storage path and metadata row; full originals remain unchanged. — revised 2026-08-29 by the delivery-worker implementation
28. ✅ **Debug UI workbench:** Keep the review board additive and debug-only at `/dev/workbench`. It uses fixture data, current chat-specific tokens, and local Keep/Merge/Replace/Review notes to audit chat list, profile/settings, chat modes, states, learning-history markers, and similar treatments without mutating production components or user state. — locked 2026-08-29
29. ✅ **Launch invite redesign:** Create and retain one ready invite while the signed-in client is online; after Copy or a chosen native-share target, prepare another unique token. Tokens have no time expiry and are atomically claimed only once a signed-in recipient is known. A claim creates both membership rows with `learning_language = 'en'` and a null `practice_language_selected_at`; selecting any language in the chat stamps that participant’s row. The client preserves only the most recently opened pre-auth token, resumes it after normal email authentication, and reuses an existing pair chat without changing either participant’s learning language. The no-app web path is one static landing template; it never validates or claims tokens. Invite creation is disabled while offline, while a pending valid claim resumes automatically after reconnection. — locked 2026-09-07 by `2026-09-07-invite-flow-redesign-design.md`


30. ✅ **Invite verification repairs:** On Android, invite text uses the native Sharesheet with `ChooserResult` for Copy/selected targets (API 35+) and the legacy selected-component/clipboard-match fallback on older Android; other platforms retain `share_plus`. One account-scoped prepared token survives leaving/reopening the invite page and network changes. The static landing carries the token only in Play’s encoded install referrer; the Android Install Referrer library retrieves it once and the app resolver validates it before auth continuation. Store-install and production-domain verification remain deferred, not claimed by local tests. — locked 2026-09-07 during the owner-authorized invite audit

31. ✅ **Required-language-sheet layout (2026-09-08, US-027):** The owner’s reference is bottom-anchored with a 520 logical-pixel content height plus the device bottom safe inset, clamped on short screens; the conflicting absolute y-coordinate is not used. Rows use a stable 56 logical-pixel minimum and grow with text scaling. Scrollbar proportions derive from visible content rather than a fixed thumb height. Keep system typography per Resolved Decision #6 (Roboto on Android, SF Pro on iOS), matching the supplied sizes/weights. Only the mandatory initial-choice sheet is restyled; the later Change language sheet remains outside scope. A fresh chat starts unselected; tapping shows bold text and a 20 px terracotta check alongside the saving indicator, then closes only after successful persistence. The empty-state card is suppressed until initial language selection completes; the taller sheet and larger rows implement the owner’s later spacing refinement.

32. ✅ **Acknowledged invite setup refresh (2026-09-09, US-027):** Track successful selection revisions while refreshing the chat list. Discard an in-flight snapshot started before a confirmed choice and refetch before replacing list/cache state; a completed choice must not reopen mandatory setup. Acknowledged local state remains visible if the follow-up request fails.

## Open Decisions

Still need a call. Surface them, don't silently choose.

1. **Word lookup data source:** bundled JSON per language pair (proposed) vs static CDN vs lightweight API
2. **Analytics:** none vs PostHog vs Supabase log queries only
3. **iOS-native feel on Android:** all-purple + Cupertino-style across both platforms (proposed) vs Material on Android / Cupertino on iOS

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
