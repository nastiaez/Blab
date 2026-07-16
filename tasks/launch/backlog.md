# Blab Launch Remediation Backlog

Audit baseline: [`../mvp-launch-audit-2026-07-15.md`](../mvp-launch-audit-2026-07-15.md)

Workflow: [`README.md`](./README.md)
Active item: `None` (`L-03` passed; `L-04` pending start)

This is the operational launch queue. Audit IDs remain stable; `L-*` IDs define execution order and may group tightly coupled evidence.

## Launch blockers

| Order | Work ID | Audit ID | Scope | Depends on | Status | Work record |
| ---: | --- | --- | --- | --- | --- | --- |
| 0 | L-00 | P0-08 | Approve launch security model: E2EE, AI translation, plaintext boundaries, consent, and public claims | None | Complete | [`items/L-00.md`](./items/L-00.md) |
| 1 | L-01 | P0-04 | Remove authenticated development pairing and verify consent-only membership creation | L-00 | Complete | [`items/L-01.md`](./items/L-01.md) |
| 2 | L-02 | P0-01 | Remove production dev entry points and boot into the real product journey | L-01 | Complete | [`items/L-02.md`](./items/L-02.md) |
| 3 | L-03 | P0-02 | Preserve and resume invite state through signup/sign-in | L-02 | Complete | [`items/L-03.md`](./items/L-03.md) |
| 4 | L-04 | P0-03 | Configure release signing and verified Android App Links | L-03 | Not started | `items/L-04.md` |
| 5 | L-05 | P0-05 | Make password change real and provider-aware | L-02 | Not started | `items/L-05.md` |
| 6 | L-06 | P0-06 | Enforce privacy toggles at transport boundaries | L-00 | Not started | `items/L-06.md` |
| 7 | L-07 | P0-07 | Complete operator policy, account deletion web path, and moderation operations | L-00 | Not started | `items/L-07.md` |

## Core MVP requirements

| Order | Work ID | Audit ID | Scope | Depends on | Status | Work record |
| ---: | --- | --- | --- | --- | --- | --- |
| 8 | L-08 | P1-11 | Tighten profile, message-update, and read-receipt RLS boundaries | L-01, L-06 | Not started | `items/L-08.md` |
| 9 | L-09 | P1-10 | Account-scope pending sends and add send idempotency | L-08 | Not started | `items/L-09.md` |
| 10 | L-10 | P1-03, P1-04 | Persist replies and enforce the approved edit contract | L-08 | Not started | `items/L-10.md` |
| 11 | L-11 | P1-05 | Prevent duplicate pair chats during invite claims | L-03, L-08 | Not started | `items/L-11.md` |
| 12 | L-12 | P1-07 | Align translation length, source-language behavior, triggering, and product claims | L-00 | Not started | `items/L-12.md` |
| 13 | L-13 | P1-08, P1-09 | Secure translation authorization, quotas, cache integrity, provider routing, and retention | L-12 | Not started | `items/L-13.md` |
| 14 | L-14 | P1-01 | Implement or remove profile and photo editing from launch scope | L-00 | Not started | `items/L-14.md` |
| 15 | L-15 | P1-02 | Implement persisted interface localization or remove unsupported claims | L-00 | Not started | `items/L-15.md` |
| 16 | L-16 | P1-13 | Add message-history pagination, page-aware translation hydration, and correct reconnect/offline behavior | L-09, L-13 | Not started | `items/L-16.md` |
| 17 | L-17 | P1-06 | Approve and implement notifications, or explicitly constrain the launch | L-00 | Not started | `items/L-17.md` |
| 18 | L-18 | P1-12 | Separate environments and verify deployed Supabase/OpenRouter state | L-13 | Not started | `items/L-18.md` |

## Release hardening

| Order | Work ID | Audit ID | Scope | Depends on | Status | Work record |
| ---: | --- | --- | --- | --- | --- | --- |
| 19 | L-19 | P2 | Remove raw errors, decide Android backup policy, reconcile release metadata, update deprecated Supabase local config, and make client grants reproducible from migrations | L-00 | Not started | `items/L-19.md` |
| 20 | L-20 | P2 | Add CI and critical integration/release test coverage | L-03, L-08, L-13 | Not started | `items/L-20.md` |
| 21 | L-21 | P2 | Reconcile PRD, tech spec, progress, privacy, Data Safety, and store listing | L-04, L-07, L-12, L-14, L-15, L-17 | Not started | `items/L-21.md` |
| 22 | L-22 | P2 | Produce final store assets, reviewer access, and submission package | L-21 | Not started | `items/L-22.md` |
| 23 | L-23 | All | Repeat full audit against the Play-signed build and deployed production services | L-01 through L-22 | Not started | `items/L-23.md` |

## Backlog rules

- `L-00` is first because it controls storage, AI, privacy, documentation, and architecture decisions across later fixes.
- Do not mark a row `Complete` until its work record contains owner manual-pass or decision-approval evidence.
- Do not use `Deferred` to hide a launch claim. Deferral is valid only after the feature/control is removed from UI and all relevant product, legal, and store promises.
- Add newly discovered defects to the audit follow-up section of the active work record, then create a new backlog row with severity and dependencies. Do not expand the active item's scope without approval.
- `L-23` produces the final `GO`, `CONDITIONAL GO`, or `NO-GO` decision.
