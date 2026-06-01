# Ship-Fast Plan — Portfolio first, Play Store v1 second

**Date:** 2026-06-01
**Owner:** Nastia (designer + PM) · Claude (build)
**Status:** approved, ready for plan files

---

## Goals (in order)

1. **Portfolio-ready screenshots.** App looks finished, brand-consistent, one beautiful demo chat. No backend or real translation required for this.
2. **Play Store v1.** Real backend, real invites, real translation for 2 language pairs only, no E2EE, no push.
3. **Post-launch.** Distribution, fixes, then E2EE, push, iOS, more languages.

## Decisions locked this session

- **No E2EE in v1.** Plaintext at rest + Supabase RLS + EU region. Privacy screen says so honestly. E2EE = v1.1.
- **No push in v1.** Foreground in-app banner only. Push = v1.1.
- **Translation ships for 2 pairs only:** Tamil ↔ English, Ukrainian ↔ English. The other 9 languages stay selectable in the picker but show "Translation coming soon" in chat; or get hidden behind a feature flag — TBD when 2.7 lands.
- **No iOS in v1.** Phase 3.1 + 3.2 deferred until Android shows traction.
- **Portfolio precedes v1 work.** Track A finishes first. Track B starts after screenshots are taken.

## Track A — Portfolio (do first)

Runs in parallel to whichever Step 2.2 chat session is still finishing Task 14.

| Step | What | Owner | Effort |
|---|---|---|---|
| A1 | **Brand swap in-app.** Purple → final orange palette + type tokens. One sweeping pass across every screen. | Nastia picks palette + type; Claude applies | 3–5 days |
| A2 | **Polish one hero demo chat.** Tamil↔English (already seeded). Tighten copy, timing, message balance, word selection for tappable tokens. | Nastia copy; Claude wire | 1 day |
| A3 | **Screenshot pass.** Chat list, chat view, word popup, language picker, profile, invite landing, empty state. Device frame, locale, status-bar hygiene. | Nastia art-direct | 1 day |

**Done when:** ≥6 portfolio-ready screenshots match the final brand. No mismatched purple anywhere.

## Track B — Play Store v1 (after Track A)

Picks up wherever Step 2.2 left off.

| Step | What | Notes |
|---|---|---|
| B1 | Finish 2.2 (chat sync) | already in flight |
| B2 | **NEW Step 2.7 — translation dictionary + tokenizer** | 2 language pairs only: Tamil↔EN, Ukrainian↔EN. Static JSON in `assets/dictionaries/`. Per tech-spec — no AI, no backend translation. |
| B3 | 2.3 invite links | required for 2-person product |
| B4 | 2.4 offline queue | ½ day verification — Task 12 already wired most of it |
| B5 | ~~2.5 push~~ | **skipped v1**. Foreground in-app banner only. |
| B6 | ~~2.6 E2EE~~ | **skipped v1.** Privacy screen rewritten with honest copy. |
| B7 | **NEW Step 3.0 — Sentry wiring + crash-free metric** | 1 day. Required for 3.4 audit. |
| B8 | **NEW Step 3.5 — Play Store assets** | Feature graphic, screenshots from Track A, short + long description, age rating, Data Safety form, hosted Privacy Policy URL + Terms URL. 2–3 days. |
| B9 | **NEW Step 3.6 — Play closed testing** | 12+ testers × 14 days. Lock down tester list early (Track A timeframe). Calendar gate. |
| B10 | ~~3.1, 3.2 iOS~~ | **deferred** until traction. |
| B11 | 3.3 splash + final store push | small |
| B12 | 3.4 pre-release audit | as written |

## Track C — Post-launch (order decided by traction)

- E2EE (former Step 2.6)
- Push (former Step 2.5)
- iOS (former 3.1, 3.2)
- Remaining 9 dictionary pairs
- UI localization (11 interface languages — strings, not just picker)
- Distribution + promotion (out of build scope; PM hat)

## Gaps surfaced during brainstorm — now tracked

- Real translation engine + dictionary content → **Track B Step 2.7**
- Brand swap purple→orange in-app → **Track A Step A1**
- UI localization 11 langs → **Track C**
- Privacy / Terms hosted URLs → **Track B Step 3.5**
- Play Store listing assets → **Track B Step 3.5**
- Play closed testing 12+ × 14d → **Track B Step 3.6**
- Sentry / crash analytics → **Track B Step 3.0**
- Demo account for Play reviewer → handled by seeded sign-up flow already; verify in 3.5

## Out of scope (re-confirmed)

- Group chats, voice/video, AI translation, language matching/discovery, payments. (PRD Non-Goals stand.)

## Open questions

- Brand palette + type — locked when?
- Tester list for Step 3.6 — start collecting names during Track A.
- Honest privacy copy text — Nastia drafts when Track B Step 3.5 lands.
