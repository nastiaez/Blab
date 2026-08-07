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
| Invite link single-use + 48h TTL (FR-4) | Postgres table + RLS policy + edge function for token mint/validate |
| Push notifications (US-038, FR-29) | **FCM via Supabase Edge Function** trigger (Supabase has no native push) |

Conventions:
- One Supabase project per environment: `dev`, `staging`, `prod`.
- All tables get RLS on day one. No service-role keys shipped in the app — Flutter uses anon key only.
- Migrations live under `supabase/migrations/` (Supabase CLI). PR-reviewed; never edit prod via dashboard.
- Generate Dart types from the Postgres schema with `supabase gen types` → checked in under `lib/shared/models/db/`.

**Out of scope for backend:** language matching/discovery, payments, voice/video, group chats, and AI-generated conversation partners. Message translation is implemented through the authenticated `translate-message` Edge Function and OpenRouter.

Translation + word lookup data (tappable word popups, FR-11) is **static dictionary content**, not AI. Bundle as JSON assets per language pair under `assets/dictionaries/`. No Supabase calls in the word-lookup path. No LLM calls anywhere.

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
| SVG double-tick (gray → purple) | Custom `Icon` widget; animate color on read |
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
- Learning-aid cache identity is `(message_id, target_lang, interface_lang)`: authored text remains authoritative in `messages.body`; each row stores the learning-language output, interface-language output, detected source, tokens, and correction analysis. Matching authorized viewers share the row, while the client applies author/recipient presentation rules. Token glosses and author correction explanations follow the interface locale
- Retryable learning-aid failures remain client-local `AsyncError` entries. Manual Retry clears only the failed `(message_id, target_lang, interface_lang)` entry before re-running the server-authoritative cache/function flow
- Tapping message padding or long-pressing opens the action sheet, whose visibility-icon section reads the exact authorized `messages.body`; tappable learning words retain their definition gesture

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
13. ✅ **Invite link policy:** Valid until a single *successful* claim, within a 48h TTL. Multiple clicks before claim are allowed. Once claimed, link returns "already claimed" state (US-037). — locked 2026-05-28
14. ✅ **Interface-language behavior:** English, Ukrainian, German, and Spanish are the launch interface locales, with English default/fallback and account-scoped persistence. Interface language controls chrome, the bottom message lane, word definitions, and correction explanations. Translation rows are cached separately by learning and interface language. Authored text remains authoritative and available through View original; authors writing in a third language keep that original in their bottom lane. — revised 2026-07-18 by L-15
15. ✅ **Log-out UX:** Confirm dialog before sign out ("Log out?" / Cancel + Log out). Signal pattern. — locked 2026-05-28
16. ✅ **Palette + type tokens (final v1 swap):** Brand `#D4694A` (press `#BB573B`, soft `#F3DAD0`). App + chat canvas cream `#EFEBE2`. White surface for headers/sheets/incoming bubble + (per-screen) status-bar safe area. Ink `#1F3340`, stone `#9A9490`, line `#E4DCCC`. Input focus border `#E19680` (softer than brand to avoid alarm). Selected-row tint `#FAF1EC`. Outgoing bubble = solid brand, white text. Avatars = deterministic warm swatch from `[#D4694A, #5E8B8C, #C99846, #1F3340, #9A6A8C, #5F7A52]` keyed by name; no gradients. Read tick + links = brand. System fonts only (Roboto on Android, SF Pro on iOS — same as #6). Source: `claude_design/blab-theme.css` UI kit. — locked 2026-06-01
17. ⛔ **Portfolio-mode live translation backend (retired):** The historical public `translate-portfolio` demo endpoint was removed with L-13 after portfolio mode left the app. It must not be deployed for launch. Historical design remains in `docs/superpowers/specs/2026-06-02-portfolio-live-translate-design.md`. — retired 2026-07-17
18. ✅ **Launch translation security:** The Flutter client submits only a message ID to the JWT-verified `translate-message` Edge Function. Postgres derives the authorized source body and caller's learning language, enforces active membership plus the translation cutoff, and atomically reserves the approved per-account quota only on a cache miss. Only the server can write `message_translations`, and writes compare a SHA-256 source hash to reject edit races. OpenRouter requests use `openai/gpt-4o-mini` through any eligible endpoint with `zdr=true`, `data_collection=deny`, fallback routing enabled, and required parameter support. The live ZDR catalog currently exposes this model through Azure, but Blab no longer hard-codes Azure as the only provider. — revised 2026-07-21 by owner approval
19. ✅ **Same-language writing correction:** The learning-aid contract returns exactly one mode: `translation` when source differs from the learning target, `correction` for a clear mistake in that target, or `none` for correct writing. Matching learning/interface locales reuse one cache row. The author alone sees correction marks and a localized explanation; recipients see the clean corrected result. Ambiguous author corrections are labeled as possible and the provider must make the smallest defensible change without inventing missing meaning. — revised 2026-07-18 by owner approval during L-15
20. ✅ **Gallery attach picker:** custom in-app photo grid (`photo_manager`) replaces the Android system photo picker for the chat gallery-attach flow, matching WhatsApp/Telegram rather than the OS-branded picker sheet. Camera capture still goes through `image_picker`. Requires `READ_MEDIA_IMAGES` + `READ_MEDIA_VISUAL_USER_SELECTED` (Android 14+ partial-access) permissions declared in the manifest; a denied/partial state shows an in-app prompt with a link to system settings rather than failing silently. — locked 2026-08-06

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
