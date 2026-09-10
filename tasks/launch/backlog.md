# Blab Launch Remediation Backlog

Audit baseline: [`../mvp-launch-audit-2026-07-15.md`](../mvp-launch-audit-2026-07-15.md)

Workflow: [`README.md`](./README.md)
Active item: `L-17` (`Awaiting manual`), with final physical Android verification
deferred to the end-of-launch device pass. `L-04` remains externally blocked, so
no not-started item is currently dependency-ready.

Tracker coordination: the owner-facing tracker now groups the active local work under
Current focus, begins with the invite flow, and preserves owner-confirmed task states.
The tracker’s post-launch invite-urgency exploration is deliberately separate from the
launch rule that an unclaimed link remains valid until successfully claimed.

This is the operational launch queue. Audit IDs remain stable; `L-*` IDs define execution order and may group tightly coupled evidence.

## Active invite verification — 2026-09-10

**Installed-app tap test — failed:** Owner-requested Alice browser/Bob emulator repeat used real external browser link taps. Default routing opens the download page, not Blab; the association endpoint is 404. With temporary user link approval only, existing-pair reuse, fresh signup, required language setup, messages, cold-start repeat and claimed/invalid states pass. Approval was removed and default failure reproduced. Evidence: `docs/qa/2026-09-10-installed-invite/`. Next: correct signed-app domain association and repeat without overrides; private Play installation remains separate. Owner-approved sharing/Copy stays done.

**Owner-approved sharing/copy — done (2026-09-10):** Owner reviewed exact clipboard contents and explicitly asked to mark social sharing and copying done. This accepts the narrowed check: Telegram dispatch, Messages draft/return, native Copy and dismissal. WhatsApp and authenticated Telegram/email recipient delivery were not tested. The owner cancelled all additional Telegram login and purchase work; the pending browser login was closed. Evidence: `docs/qa/2026-09-10-share-targets/`.

Current priority: final owner review of no-expiry/failure-retry behavior already exercised in browser/emulator, then verified installed-app and private Play install handoff. Alice browser/Bob emulator evidence is in `docs/qa/2026-09-09-browser-emulator/`; local integration and 15 database checks passed. Current repairs have 78 focused checks. Source commit/push is complete on `fix/invite-flow-verification`; share acceptance does not mark all remaining invite or store gates complete.

Step 2.3b has a local verification record at
`docs/qa/2026-09-08-invite-flow/README.md` with actual screenshot proof. Owner checks remain pending for
English/first-language selection, Back and save-error recovery, offline invite
continuation, new/returning recipients, and existing-pair reuse. Native sharing/Copy now has explicit owner approval.
The static landing and Play install-referrer handoff are included in implementation;
real store installation and public Loveblab domain verification are deferred until
the owner’s final domain/release pass. Local Alice/Bob two-way messages and
independent English/German choices, installed recipient, normal signup, native
Copy, and same-pair re-invite have been exercised; these do not substitute for owner confirmation.

Owner refinement on 2026-09-08: `Only one friend can use this link` now sits below the invite card without a bullet; Android screenshot 23 records the latest copy. Invite owner checks remain pending.

The required first-language sheet now follows the owner’s warm-white, divided-list styling with a slim scrollbar and subtle 8% warm veil. The later spacing refinement increases rows to 56 px and sheet content to 520 px, and hides the empty-state card until language setup completes. The original no-dimming treatment is superseded; owner review includes scrolling, language selection, and Back/recovery. No owner checkbox is marked complete by these visual changes.

## Launch blockers

**Independent fallback test (2026-09-10):** No existing signed APK/AAB was found locally or in GitHub releases/artifacts. With temporary Android user link selection, a fresh Alice invite opened Bob Link QA’s existing chat, Bob’s new message reached Alice’s browser, and a cold-start repeat reopened the same chat. User selection was restored to disabled afterward; no forced verification or production debug certificate was used. This is conditional journey evidence, not automatic association or Play proof. See `docs/qa/2026-09-10-self-test/README.md`.

**Google confirms the website association (2026-09-10):** Public verification returns `linked: true` for the approved release identity. Matching-app testing is still waiting for the original signing backup; the bounded 1Password account lookup returned no data before timing out.

**Association publication resolved (2026-09-10):** Owner commit `fefed30` published successfully; the live permanent-domain association is HTTP 200 JSON with the approved controlled release certificate. Previous Vercel publication failure below is historical. Remaining installed-link prerequisite is a matching signed app/restored original signing files; Play identity and actual install/referrer tests are still open.

**Installed-link fix source ready, publication blocked (2026-09-10):** `nastiaez/blab-landing` main `db051ec` adds the missing association using the already approved controlled release certificate, not the emulator debug certificate. Four site checks pass, homepage unchanged. Vercel rejected the deployment because Git author `aswinckr` lacks project access. Need owner-triggered publication plus a matching signed app; original key files are missing locally and the Play app-signing certificate is still unverified. Full evidence: `docs/qa/2026-09-10-app-link-fix.md`.

**Private Play test prerequisites (2026-09-10):** Original upload-signing files are absent at their recorded locations and must be restored from the owner-confirmed backup, not replaced. Production configuration still contains three placeholders; hosted parity needs verification. The permanent-domain association returns 404, although the invite fallback is 200. Obtain the actual Play app-signing certificate and finish release configuration before claiming a Play installation pass. No release package/upload or owner gate completed.

**Invite website publication verified (2026-09-09):** Owner commit `01e2651` published successfully through the existing Vercel connection. Both public invite routes return HTTP 200; mobile browser checks confirm logo navigation, invite referrer, and unchanged homepage. Website-access blocker is resolved. Remaining release gates: actual App Store listing, verified Google Play install path, Play signing association, and owner manual handoff tests; these are not marked complete.

| Order | Work ID | Audit ID | Scope | Depends on | Status | Work record |
| ---: | --- | --- | --- | --- | --- | --- |
| 0 | L-00 | P0-08 | Approve launch security model: E2EE, AI translation, plaintext boundaries, consent, and public claims | None | Complete | [`items/L-00.md`](./items/L-00.md) |
| 1 | L-01 | P0-04 | Remove authenticated development pairing and verify consent-only membership creation | L-00 | Complete | [`items/L-01.md`](./items/L-01.md) |
| 2 | L-02 | P0-01 | Remove production dev entry points and boot into the real product journey | L-01 | Complete | [`items/L-02.md`](./items/L-02.md) |
| 3 | L-03 | P0-02 | Preserve and resume invite state through signup/sign-in | L-02 | Complete | [`items/L-03.md`](./items/L-03.md) |
| 4 | L-04 | P0-03 | Configure release signing and verified Android App Links; register the Play app-signing certificate with production Google OAuth | L-03 | Blocked | [`items/L-04.md`](./items/L-04.md) |
| 5 | L-05 | P0-05 | Make password change real and provider-aware | L-02 | Complete | [`items/L-05.md`](./items/L-05.md) |
| 6 | L-06 | P0-06 | Enforce privacy toggles at transport boundaries | L-00 | Complete | [`items/L-06.md`](./items/L-06.md) |
| 7 | L-07 | P0-07 | Complete operator policy, account deletion web path, and moderation operations | L-00 | Complete | [`items/L-07.md`](./items/L-07.md) |

## Core MVP requirements

| Order | Work ID | Audit ID | Scope | Depends on | Status | Work record |
| ---: | --- | --- | --- | --- | --- | --- |
| 8 | L-08 | P1-11 | Tighten profile, message-update, and read-receipt RLS boundaries | L-01, L-06 | Complete | [`items/L-08.md`](./items/L-08.md) |
| 9 | L-09 | P1-10 | Account-scope pending sends and add send idempotency | L-08 | Complete | [`items/L-09.md`](./items/L-09.md) |
| 10 | L-10 | P1-03, P1-04 | Persist replies and enforce the approved edit contract | L-08 | Complete | [`items/L-10.md`](./items/L-10.md) |
| 11 | L-11 | P1-05 | Prevent duplicate pair chats during invite claims | L-03, L-08 | Complete | [`items/L-11.md`](./items/L-11.md) |
| 12 | L-12 | P1-07 | Align translation length, source-language behavior, triggering, and product claims | L-00 | Complete | [`items/L-12.md`](./items/L-12.md) |
| 13 | L-13 | P1-08, P1-09 | Secure translation authorization, quotas, cache integrity, provider routing, and retention | L-12 | Complete | [`items/L-13.md`](./items/L-13.md) |
| 14 | L-14 | P1-01 | Implement or remove profile and photo editing from launch scope | L-00 | Complete | [`items/L-14.md`](./items/L-14.md) |
| 15 | L-15 | P1-02 | Implement persisted interface localization or remove unsupported claims | L-00 | Complete | [`items/L-15.md`](./items/L-15.md) |
| 16 | L-16 | P1-13 | Add message-history pagination, page-aware translation hydration, and correct reconnect/offline behavior | L-09, L-13 | Complete | [`items/L-16.md`](./items/L-16.md) |
| 17 | L-17 | P1-06 | Approve and implement notifications, or explicitly constrain the launch | L-00 | Awaiting manual | [`items/L-17.md`](./items/L-17.md) |
| 18 | L-18 | P1-12 | Separate environments and verify deployed Supabase/OpenRouter state | L-13 | Complete | [`items/L-18.md`](./items/L-18.md) |
| 24 | L-24 | Follow-up | Repair Android warm invite-link routing; received links must navigate while Blab is already open | L-03, L-04 | Not started | `items/L-24.md` |
| 25 | L-25 | Follow-up | Preserve each participant's completed learning-language history across a later language change | L-16, L-18 | Awaiting manual | [`items/L-25.md`](./items/L-25.md) |

## Release hardening

| Order | Work ID | Audit ID | Scope | Depends on | Status | Work record |
| ---: | --- | --- | --- | --- | --- | --- |
| 19 | L-19 | P2 | Remove raw errors, decide Android backup policy, reconcile release metadata, update deprecated Supabase local config, stabilize local service versions/cold starts, and make client grants reproducible from migrations | L-00 | Complete | [`items/L-19.md`](./items/L-19.md) |
| 20 | L-20 | P2 | Add CI and critical integration/release test coverage | L-03, L-08, L-13 | Complete | [`items/L-20.md`](./items/L-20.md) |
| 21 | L-21 | P2 | Reconcile PRD, tech spec, progress, privacy, Data Safety, and store listing | L-04, L-07, L-12, L-14, L-15, L-17 | Not started | `items/L-21.md` |
| 22 | L-22 | P2 | Produce final store assets, reviewer access, and submission package | L-21 | Not started | `items/L-22.md` |
| 23 | L-23 | All | Repeat full audit against the Play-signed build and deployed production services, including physical startup/ANR and OAuth checks | L-01 through L-22 | Not started | `items/L-23.md` |

## Backlog rules

- `L-00` is first because it controls storage, AI, privacy, documentation, and architecture decisions across later fixes.
- Do not mark a row `Complete` until its work record contains owner manual-pass or decision-approval evidence.
- Do not use `Deferred` to hide a launch claim. Deferral is valid only after the feature/control is removed from UI and all relevant product, legal, and store promises.
- Add newly discovered defects to the audit follow-up section of the active work record, then create a new backlog row with severity and dependencies. Do not expand the active item's scope without approval.
- `L-23` produces the final `GO`, `CONDITIONAL GO`, or `NO-GO` decision.
