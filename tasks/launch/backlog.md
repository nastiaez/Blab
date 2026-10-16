# Blab Launch Remediation Backlog

Audit baseline: [`../mvp-launch-audit-2026-07-15.md`](../mvp-launch-audit-2026-07-15.md)

Workflow: [`README.md`](./README.md)
Active item: `L-17` (`Awaiting manual`), with final physical Android verification
deferred to the end-of-launch device pass. `L-26` records the newly confirmed
offline-translation recovery gap and remains queued until the active manual gates
are resolved or the owner explicitly reprioritizes it.

Tracker coordination: the owner-facing tracker now groups the active local work under
Current focus, begins with the invite flow, and preserves owner-confirmed task states.
The tracker’s post-launch invite-urgency exploration is deliberately separate from the
launch rule that an unclaimed link remains valid until successfully claimed.

## Temporary auth-refresh outage — 2026-10-16 (in progress)

Owner message13259 requests investigation and repair of Sentry FLUTTER-6.
One production19 event/user, paused/background app; no evidence of a widespread
outage or process termination. Confirmed retryable errors were forwarded to
FlutterError and the session provider. Preserve session state on this typed
failure, retain unexpected-error reporting and genuine sign-out, and prevent
retryable server text from being classified as revoked. Tracker
`journey-auth-refresh-recovery` remains unchecked pending physical-device manual acceptance. Owner approved13274; Android25 released from a48919d after all3 CI gates passed to the existing public2/test8 testers. Focused auth14/backend188 checks pass; Android5562 deterministic HTTP
outage→refresh failure→successful renewal passes, screenshots delivered13272.
No physical/live-backend or automatic-refresh-timing acceptance claimed.
Evidence: `docs/qa/2026-10-16-auth-refresh-recovery`.

## Participant-form relevance — 2026-10-15 (in progress)

Confirmed hosted German `Schreib deiner Mutter` has incorrect recipient
alternatives `deiner/deinem`. Reject noun-case-only choices on the server and
client, release invalid persisted note ownership, and preserve real participant
agreement plus valid frozen history. Dedicated current-main worktree;929 Flutter
and210 backend checks pass, four live candidate audit cases pass and actual
Android/browser Change/restart/two-way behavior inspected. Pending-save Back
also retains account-owned reconciliation. Owner acceptance and release pending. Tracker
`core-participant-form-relevance` remains unchecked. Evidence:
`docs/qa/2026-10-15-german-form-note/README.md`.

## Completed Hindi/Tamil reading-script work — 2026-09-14

Owner approved the completed account-wide `Reading script` choice for Hindi and Tamil, native by default. The existing Translation preferences row and checkmarked choice sheet are reused in Profile and eligible chats; complete cached generated sentences switch immediately, while authored/Original text and native audio remain unchanged. Alice-browser/Bob-Android and Profile evidence, automated verification, owner confirmation, commit, and the `main` push are complete under Step 2.14.

This is the operational launch queue. Audit IDs remain stable; `L-*` IDs define execution order and may group tightly coupled evidence.

## Active grammatical-form verification — 2026-09-10

**New visible-preview defect (2026-09-11):** Chats preview can show canonical feminine while the message bubble uses resolved masculine. Reproduced with Bob's “Did you go to the park today?” after restart. Unchecked follow-up; the note redesign does not claim to repair the preview path.

**2026-09-11 redesign — in progress:** Owner replaces chooser/markers and next-message expiry with complete name-suggested forms (feminine fallback), one persistent note per participant/chat, and Change → existing Translation preferences. Correct author/recipient attribution before suggesting. Annotated message and future messages update; other history stays frozen. Local browser/emulator note, settings correction, no-repeat and restart checks pass; owner verification/full matrix remain pending. Evidence: `docs/qa/2026-09-11-automatic-forms/README.md`. Earlier correction-window evidence is historical, not acceptance of this replacement.

**Correction window — awaiting owner check (2026-09-11):** Owner approved one message per chat: latest successful explicit choice, any send date, until the next same-chat sent/received message. Change and matching Settings edit that message; older completed history stays fixed. Persistence, chooser repair, accessibility-state preservation and prepared-history alternatives verified on Alice browser/Bob emulator. 33 focused and 52 regression checks pass; both packages produced. Evidence: `docs/qa/2026-09-10-form-correction-window/README.md`. Wrong-person and false-success translation validation remain separate open defects.

**Root-cause investigation (2026-09-10):** Confirmed unchecked wrong-person metadata; wrong source-language/none accepted as success, suppressing Retry; prepared-history loading drops form alternatives; temporary choice can override updated settings; selection/confirmation condition fails in isolated and full-chat diagnostics. Externally selected Change control passes, so the exact prior inert tap still needs integration isolation. Existing spec intentionally leaves older completed messages unchanged after settings changes. No fixes made. See `docs/qa/2026-09-10-ukrainian-forms/ROOT-CAUSES.md`.

**Ukrainian manual test (2026-09-10):** Alice browser/Bob emulator reproduced three failures: incoming “you” chooser identifies/saves the partner instead of the viewer; temporary Change does not reopen options; outgoing English “I was tired yesterday.” remains English for Ukrainian (stored source uk, aid mode none). Feminine rendering and settings fallback persistence across restart pass in isolation. No fixes made; full matrix stays open. Evidence: `docs/qa/2026-09-10-ukrainian-forms/README.md`.

## Active invite verification — 2026-09-10

**Owner deferral (2026-09-10):** Owner explicitly deferred testing automatic installed-app invite opening until after launch. Keep this test unverified and unchecked, not passed; original signing/matching-app prerequisite still applies when resumed. This deferral does not approve or complete the separate Play install → signup → invite continuation test. Existing local no-expiry, failure/retry, conditional browser/emulator and approved sharing evidence remains valid; source is committed and pushed.

**Installed-app tap test — failed:** Owner-requested Alice browser/Bob emulator repeat used real external browser link taps. Default routing opens the download page, not Blab; the association endpoint is 404. With temporary user link approval only, existing-pair reuse, fresh signup, required language setup, messages, cold-start repeat and claimed/invalid states pass. Approval was removed and default failure reproduced. Evidence: `docs/qa/2026-09-10-installed-invite/`. Next: correct signed-app domain association and repeat without overrides; private Play installation remains separate. Owner-approved sharing/Copy stays done.

**Owner-approved sharing/copy — done (2026-09-10):** Owner reviewed exact clipboard contents and explicitly asked to mark social sharing and copying done. This accepts the narrowed check: Telegram dispatch, Messages draft/return, native Copy and dismissal. WhatsApp and authenticated Telegram/email recipient delivery were not tested. The owner cancelled all additional Telegram login and purchase work; the pending browser login was closed. Evidence: `docs/qa/2026-09-10-share-targets/`.

Current priority: final owner review of no-expiry/failure-retry behavior already exercised in browser/emulator, then the separate private Play install handoff. Automatic installed-app opening verification is owner-deferred until after launch. Alice browser/Bob emulator evidence is in `docs/qa/2026-09-09-browser-emulator/`; local integration and 15 database checks passed. Current repairs have 78 focused checks. Source commit/push is complete on `fix/invite-flow-verification`; share acceptance does not mark all remaining invite or store gates complete.

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

**Private Android recovery (2026-10-10):** Original signing material restored; existing production backend restored and parity verification passes after 32 owner-approved migrations and four function deployments. Generated translation cache cleared without backup as explicitly approved; 26 accounts and 229 original messages retained. Existing Play listing confirmed. Owner-approved GitHub connection restored access to the existing Blab Sentry project; production environment validation now passes. Signed 1.0.0 (5) received by Firebase; download-back checksum matches the exact emulator-tested APK. Cold launch and same-version interface-language retention pass. Direct-download Android OAuth identity and the approved tester allowlist are configured. Firebase invitation was sent with exact-note approval; the owner then reported the old sign-in entry. The latest onboarding is present but the hosted rollout is off. A private-artifact-only preview is being prepared; crash-event receipt, real account/chat tests, Play-signed update retention and owner phone acceptance remain pending. Earlier missing-key/backend findings below are historical.

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
| 26 | L-26 | Follow-up | Restore previously completed message and photo-caption translations from the account-scoped device cache after an offline restart | L-13, L-16 | In progress | [`items/L-26.md`](./items/L-26.md) |

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


## Seamless messaging regression — 14 October 2026

High priority, in progress; owner review pending. Fix slow/missing Practice translations, grey Normal text, text erase/reveal replay, and delayed chat entry. Hosted text-first configuration was absent; claimed translation jobs executed serially. Verify both viewers, all eleven learning languages, burst ordering, reopening, failures and actual Android motion before acceptance. `core-seamless-translation` remains unchecked.

- Seamless verification update: server-job ownership/list fan-out fix and bounded pending recovery added. Funding restored by owner; 22-send/44-viewer sweeps completed. Final context/form refinements and actual-client proof in progress; owner review and production rollout remain pending.

- 2026-10-14 21:05 — Exact-source funded acceptance complete:22 sends/44 readable viewer results/44 word-help packages, median2.874s/max6.256s; actual two-client context follow-ups2.918–6.756s.185 backend pass; unchanged Dart894 pass/15 skip. Tamil, fragment/form-review and malformed-optional-form regressions fixed. Actual Android/browser media retained in docs/qa/2026-10-14-seamless-translation. Funding block superseded; owner visual review, hosted rollout and integrated Firebase release still pending.

- Release completed 2026-10-14: approved source3361abb synchronized to main; production translate-message/prepare-message-jobs deployed and seven runtime source files read back identical. Backend environment verification and unauthenticated401 gates passed. Signed v16 APK SHA256 e795d7fdd1db3fbf82e148754eff8e7f6e6d7d465baced45e4a0dd301d17e0b5 replaces signed v15 on emulator5560, retains German, cold-launches successfully. Main CI38625954861 all three jobs passed. Firebase release3lm50l43b9k0o received exact download-back checksum and distributed to the existing two testers (both Accepted). Physical phone/authenticated-history retention remains unverified. Owner-facing checkbox remains unchecked pending actual phone acceptance. No chat-history cutover enabled.


## v16 translation reliability follow-up — 2026-10-14

High priority, in progress. Owner reports repeated translation errors and missing Practice word popups after v16. Research confirms a reproducible source-language validation defect, conflicting deadlines, minute-based retry wakeups and shared sentence/metadata capacity. Assessment: `docs/operations/translation-reliability-assessment-2026-10-14.md`. New tracker item `core-translation-recovery-v16` stays unchecked until actual owner acceptance. No runtime changes in the research checkpoint; prior release is not a pass for these failures.

- Recovery candidate implemented and locally verified: `docs/qa/2026-10-14-translation-recovery/README.md`. 44 language results;12 burst viewer results≤6.906s; live popup enrichment and precise Android read-notification cancellation. Owner review pending; no hosted/release changes. Legacy untagged notifications, independent gateway redundancy and large-load SLO remain explicit limits.

## One-call translation and live-chat recovery — 2026-10-15

High priority; candidate verified, awaiting owner review. Tracker core-single-call-live-recovery remains unchecked. Scope: eliminate22-request amplification, recover missing incoming messages in both directions, and resolve stale shimmer without reopening.165 backend/913 Flutter checks,9 live cases, two-device Android + disabled-publication recovery evidence: docs/qa/2026-10-15-single-call-reliable-chat. No production deploy/merge/release. Historical per-phase/audit recommendations above are superseded for this authorized candidate by the one-call design.

## Composer emoji input — 15 October 2026

Non-launch feature, Later; owner approved the two SVG icons and requested implementation in Telegram12800. Dedicated current-main worktree. Inline composer picker uses the existing emoji engine; no GIF/sticker/backend changes. Android/Web review and owner manual pass pending; `later-composer-emoji` remains unchecked. No merge/release authorized by icon approval. Evidence: `docs/qa/2026-10-15-composer-emoji/`.

Emoji visual/workflow approval12822 recorded; owner requests holding it for the next release, with more work to add. No immediate distribution. Owner physical-device manual test remains separate.

## Jump to latest messages —15 October2026

Later, request12824. Floating down-arrow while browsing older history; return to latest without changing draft/focus. Android candidate verified; owner review pending, `later-jump-latest` unchecked. Evidence: docs/qa/2026-10-15-jump-to-latest/.

## v20 delivery —15 October2026

Approved12910; grammatical-form relevance, emoji composer/polish and centered jump-to-latest are integrated and Firebase20 is distributed to the existing two testers. OK/okay/shared translation rulebook retained from19. Combined proof in docs/qa/2026-10-15-reviewed-chat-release-v20. Physical-device owner manual acceptance remains pending; tracker checkboxes intentionally remain unchecked.

## Google sign-in handoff — 2026-10-16 (in progress)

Owner13339 reports first-login failure with later restart recovery. Authenticated
test account is approved; onboarding did not advance. Native-resume access check
unmounts the auth route, invalidating its async callback. Red-green widget proof
retains route state without exposing denied content. Production channel bypasses
the gate; separate shared-handoff verification required. Owner screenshot review,
native proof and release remain pending.

Google handoff evidence:953 Flutter passes/15 pre-existing skips,8 focused test checks/public handoff pass, analyzer clean; native iPhone staging and production journeys pass with synthetic provider transport. Screenshot13353 delivered; review/release and physical Google login pending.

## Balaji translation save rejection — 16 October2026 (release hold)

Owner13356 requested investigation before combined release. Both reported test
messages exhausted4 worker attempts with batch_commit_failed. Remaining strict
SQL save checks contradict the approved two-rule edge validator. Fresh English
typo replay reproduces optional explanation rejection; original German payload
was not retained, so its exact rejected field remains unknown. Candidate migration
aligns all save paths and worker preserves safe diagnostic codes. Rollback-only
proof does not deploy changes or recover chat rows. Full isolated SQL/integrated
UI verification pending. Evidence: docs/qa/2026-10-16-balaji-translation/.

## Release completed — 16 October 2026

Owner13370 authorizes launch; screenshots13353 and retry13327/13328 reviewed.
Clean CI cafe860 passes all three jobs (quality, Android release compilation,
local backend integration): https://github.com/nastiaez/Blab/actions/runs/38875756223.
Version26 distributed through existing Firebase channels: test8 / public2 testers,
release-specific invited counts verified; both download-back hashes match.
iOS26 assigned to existing groups. Test internal and external IN_BETA_TESTING;
Apple beta review APPROVED. Public existing internal Owner testing IN_BETA_TESTING.
No App Store publication or replacement/expiration of prior TestFlight builds.
Test translation backend deployed and both incident messages recovered for both
viewers with one controlled extra attempt each. Production backend unchanged.
Physical-device Google sign-in and owner manual acceptance remain unverified;
manual tracker checkboxes remain unchecked. Receipt and hashes:
projects/blab/releases/20261016-recovery-26/receipt.json and artifacts.json.

## Production parity — 16 October 2026

Owner13373 authorizes production parity and requires future verified releases to
include production unless explicitly scoped otherwise. Source2fa157e; same runtime
as7b36dab and successful CI38875756223. Applied four missing migrations atomically:
20261015000003,20261015223500,20261016000001,20261016000002. Production now has
all102 repository migrations with no missing or remote-only versions. Shared
distribution schema defaults to public/active; no test allowlists or secrets copied.
Production translate-message32 and prepare-message-jobs11 ACTIVE; all14 downloaded
TypeScript files equal verified source. Live read-only checks accept optional typo
explanation, reject empty/unreadable output, retain private helpers/attempt writes,
and return public/active access. Both unauthenticated endpoints return401.
No live chat records, quotas or failure attempts reset; no synthetic production
fixtures. This proves deployment/schema/policy parity, not a new physical-phone
end-to-end translation run. Existing owner/manual acceptance remains pending.
