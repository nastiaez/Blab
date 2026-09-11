# Local invite-flow verification — 7–8 September 2026

**Result:** Local invite creation → share → signed-in or normal email-auth continuation → required in-chat language selection → two-way conversation verified. Public Loveblab domain association and actual store-install handoff are explicitly outside this local pass. Owner launch checkboxes remain unchecked.

[Screenshot gallery](index.html) · [Four-screen proof](proof.png)

## Required language sheet — owner visual parameters

**Roomier sheet and clean background:** [Android screenshot 28](screenshots/28-language-sheet-roomier.png) shows the later owner refinement: 520 px content height, 56 px minimum language tap targets, and no empty-state card behind required setup. Existing-message rendering is unchanged. The first-message prompt returns after setup; a regression was observed failing before the change and passing afterward. All eight empty-state/required-sheet checks pass, targeted analysis is clean, and the rebuilt APK was installed and inspected. Native row bounds confirm 56 px targets, no empty-state copy is present, and scrolling reaches Ukrainian. The local Bob/Carol fixture was reset to unselected for the capture; no hosted data or owner launch checkbox changed.

Visual review of screenshot 28: IA9, interaction9, clarity9, polish8, intent10, usefulness9. Larger targets retain consistent alignment and scrolling; the background is now clear of the partially covered prompt. No blocking issue or further refinement cycle required for this scope.

**Check asset correction:** the sheet now reuses the existing `assets/icons/check - 20.svg`; the redundant custom asset was removed. [Selected/saving Android screenshot 27](screenshots/27-language-selected-existing-check.png) shows the real icon alongside the save indicator. To capture this normally brief state, the local Bob/Carol membership row was held in a bounded eight-second database transaction; it released automatically and English saved successfully. Temporary emulator network-delay probes were reset to none. The APK rebuild and all four required-sheet regression checks pass. Visual review retains scores IA9/interaction8/clarity8/polish8/intent9/usefulness9; no further icon correction needed. No hosted data, GitHub push, or owner launch checkbox changed.

[Android default text](screenshots/24-required-language-sheet.png) · [Android 1.3× text](screenshots/25-required-language-large-text.png).

Applied the warm-white surface, warm outline and upward shadow, 24 px top corners, 22/14 px header hierarchy, divided 15 px language rows, persistent 3 px scrollbar and subtle 8% warm veil. Initial selection remains unset; while saving, the selected row becomes bold with the 20 px terracotta check and separate progress indicator. No row tint or drag handle. Responsive sizing/system typography follow tech-spec Decision #31.

Verification: final Android debug build succeeded and installed on `emulator-5554`; default and enlarged-text sheet captures inspected. Scrolling reaches Ukrainian. System Back returns to Chats and reopening restores required setup. All four focused Back/retry/duplicate-selection/outside-tap/drag checks pass; targeted analysis reports no issues. Original device text size restored after capture. Owner checks remain pending.

UI/UX review (installed screen and interaction checks): information architecture 9/10; interaction design 8/10; trust and clarity 8/10; visual polish 8/10; fit to user intent 9/10; operational usefulness 9/10. The initial review caught an overly wide scrollbar track, corrected in the final capture. Header remains fixed while all eleven languages scroll; large text remains readable. No remaining blocker for this scoped sheet refinement. The existing background chat mode label truncates at larger text size; this unrelated header treatment was not changed.

## Owner refinement — helper below the invite card

Latest owner copy: **Only one friend can use this link**. [Updated Android screenshot 23](screenshots/23-invite-only-one-friend.png) was captured after rebuilding and reinstalling; the native hierarchy confirms the exact text. Visual review confirms the full line fits with the existing spacing. Scores remain IA 9, interaction 8, clarity 8, polish 8, intent 10, usefulness 9; no blocking issue or further cycle for this copy-only change. Owner launch checks remain open.

[Updated Android screenshot](screenshots/22-invite-helper-below-card.png).
Moved `One friend can use this link` outside the card, removed the bullet, and retained its 13 px muted styling. The helper sits 12 px below the card and aligns with its content. No sharing or link behavior changed.

Verification: Android debug build succeeded, installed on `emulator-5554`, and opened through Chats → New chat. Native hierarchy and screenshot confirm the helper is below the card, with a ready link, visible Back icon, and enabled Send invite. The two existing invite-screen/prepared-invite checks pass. Owner completion gates remain unchecked.

UI/UX review of the rendered refinement: information architecture 9/10; interaction design 8/10; trust and clarity 8/10; visual polish 8/10; fit to user intent 10/10; operational usefulness 9/10. The card now groups only shared content, with the supporting rule outside it. No blocking issue for this narrow refinement; no additional cycle required.

## Acceptance evidence

| Requirement | Evidence and result |
| --- | --- |
| No language choice before sharing | Actual Invite a friend screen, screenshot 17. Native Android Sharesheet, screenshot 04. |
| Completed Copy rotates link; dismissal does not | Native emulator Copy changed `6dd35d38ae2d` to `39155560907e`; subsequent dismissal retained the latter. Screenshot 06 captures the system Copy confirmation and fresh link. Prepared-token tests cover offline exposure/reconnection and account isolation. |
| Offline invite screen and recovery | Emulator network disabled: only No connection, disabled Send invite (07); re-enabled on reconnect. Resolver tests cover pending claim recovery and persistence after leaving. |
| Registered recipient opens installed app | Bob opened Carol's `05810f0ea808` invite in the installed Android app and reached the required language sheet (19). Explicit Android intent used for this local test: **not evidence of public verified-domain association**. |
| New recipient can sign up without reopening invite | Normal signup (08) created `charlie-invite-1788805861791@blab.test`; automatic claim created Charlie/Alice chat `d50d8df3-25a7-438a-a4d7-0c7c1a5e07ba` and opened its language sheet. Auth-continuation tests cover signup and existing-account login. |
| No-app/browser fallback exists and does not claim | Local `/i/{token}` renders static logo/copy/store buttons (05). Browser requests contain no Supabase validation/claim call; static-page tests enforce that boundary. Actual download/install is deferred. |
| Language choice happens in resulting chat | Alice's required sheet (10), English confirmation (11), and Bob's German confirmation (12). Both persisted selection timestamps are non-null. English first-selection bug reproduced and fixed. |
| Back and failed-save recovery | Installed Android Bob's system Back leaves Carol's sheet for Chats (20), preserving the unconfigured new connection. Regression coverage also verifies visible Back, retry after save failure, and no duplicate save/dismissal while saving. |
| Each person chooses independently; actual messaging works | Same chat `e2f94611-8cf5-47f0-aabd-285716ff7ee4`: Alice `en`, Bob `de`. Alice sent “Hi Bob! The invite worked.” and Bob replied “Hi Alice! I received your message.” Alice sees English (15); Bob sees German practice results (16). Local preparation queue is all ready (4 jobs). |
| Reinvite does not duplicate/reset an existing pair | Bob opened Alice's `ced6b3cd17ae`: same chat ID, no required sheet, English/German preserved (18). Database integration additionally checks single-pair identity and preservation. |
| New connection stays unread until selection | Carol appears Ready to chat in native Bob's Chats (20); authored first-message preview and prepared Practice preview covered by state/database tests and Alice's translated row in native Chats. |
| Old link, race, used/self/invalid branches | Local database integration exercised a 49-hour-old link, concurrent claim, repeat/pair reuse; resolver tests exercise self, claimed, invalid, retry and latest-token routing. See logs below. |
| Required setup does not prepare/read messages early | Transactional database tests verify initial selection/revision behavior, queue gating, first-message retargeting, and prepared previews. |
| Mode guidance is nonmodal | Regression verifies a single outside composer tap both dismisses the tip and focuses the input. Account-specific seen flags prevent repeat tips. |

## Repairs included

- Native Android Copy/selected-target completion and fresh-link preparation, including stale callback and account-change protection.
- Durable latest-valid-invite continuation through authentication, app return and reconnect; retryable network failures no longer become invalid-link states.
- First English selection now completes setup; first selection does not create a spurious language-history boundary. Required sheet remains usable after failures and does not await an unrelated chat-list refresh.
- Prepared message previews refresh in real time. Messages do not prepare against an unselected practice language.
- Static landing logo resolves on nested invite paths. Android install-referrer token transport is implemented and locally tested, but actual Play delivery remains unverified until release/domain work.
- Mode tips no longer consume the first composer tap; the approved pointer and 12 px padding are restored.
- Reconnection during an active request queues a retry; only a validated newer invite retires an older installation handoff, including a native lookup still in flight.

## Verification records

- [Focused invite/chat regressions](checks/focused.log): 63 passing, including final recovery-race and mode-tip checks.
- [Transactional database tests](checks/database.log): 15 passing.
- [Local database/realtime integration](checks/integration.log): passed, including old links, claim race and existing-pair preservation.
- Full-suite exploration found 11 remaining failures across four preexisting chat presentation suites. A disposable checkout of baseline `42d475c` reproduced **the exact same 11 names**, with 44 passes; these are not claimed fixed. [Baseline comparison log](checks/baseline-preexisting-failures.log).
- Final web and Android debug outputs compile successfully; the final Android package is installed and both browser sessions were reloaded and checked on that version. Logs: [web](checks/final-web.log), [Android](checks/final-android.log), [final native state](checks/final-native.xml), [database/runtime snapshot](checks/runtime.txt).
- Full analysis has a preexisting unused optional parameter warning in `test/chat_language_timeline_state_test.dart`; no new production analysis issues.

## Setup left for later verification

- Local Flutter web: `http://localhost:7358/` (separate signed-in persistent Chrome sessions for Alice and Bob).
- Local generic invite landing: `http://localhost:7360/i/{token}`.
- Local Supabase: `http://127.0.0.1:54321`; Docker services remain running.
- Android emulator `blab_pixel_api36`: signed in as Bob, reopened on Alice’s existing German-practice conversation after installing the final version. [Final native capture](screenshots/21-final-native-bob.png).
- Accounts: `alice@blab.test`, `bob@blab.test`; password for both: `Blab-local-123!` (local-only fixtures).
- Persistent browser profiles: `/tmp/blab-invite-qa/alice-profile` and `/tmp/blab-invite-qa/bob-profile`.
- Background launch agents: `sh.aswin.blab-qa-web`, `sh.aswin.blab-qa-control`, `sh.aswin.blab-qa-emulator`, `sh.aswin.blab-qa-functions`.
- Translation provider required a local environment correction: the previous free-model identifier returned 404 and its fallback returned 401. The task-only private environment selects `openai/gpt-4o-mini` through OpenRouter; actual translations succeeded. The source `.env.local` was not overwritten, and secrets are not included in this artifact. The local worker endpoint and local service credential are configured in local Vault.
- Changes are local on `fix/invite-flow-verification`; no hosted migrations, public-domain changes, commits or pushes were performed in this verification pass.

## Deferred gates — not represented as passed

Public `loveblab.com` verified App Links, production signing association, actual Play installation/referrer delivery, iOS/store release wiring, and the owner's release/share-target device matrix. Step 2.3b and owner tracker checkboxes stay open for those explicit gates.

## UI/UX review

Evidence: real Invite, required-language, native sharing, offline, landing and conversation screenshots; corresponding interaction and recovery implementations/tests.

| Category | Score |
| --- | --- |
| Information architecture | 9/10 |
| Interaction design | 8/10 |
| Trust and clarity | 8/10 |
| Visual polish | 8/10 |
| Fit to user intent | 9/10 |
| Operational usefulness | 9/10 |

**Pass for local invite scope.** Sharing has one clear action, language selection occurs with chat context, both participants retain control of their own view, and recovery stays in place. No remaining local-flow blocker identified. Public routing and release-matrix gates remain separate, not averaged into these scores.


## Public invite website — 2026-09-09

Owner-authored commit `01e26516116739c73458edb58a56de9ffbd25290` received a successful Vercel production status. Both `https://loveblab.com/i/preview` and `https://blab-landing.vercel.app/i/preview` return HTTP 200 with the approved template. Homepage hash remains `2babe0b265ab7bdeced2b9d8ef0b8ba1b62432c735fa0909705ed7c0a83ab314`.

Live Chrome at 390×844 / 2× verified: logo loads and returns to the homepage; Play link retains `invite=preview` in the install referrer; no horizontal overflow. Screenshot: `screenshots/29-live-invite-page.png`. Visual review matches the approved layout. The App Store destination is still a search placeholder; no store installation or release signing verification is claimed. Owner confirmed the GitHub save only, not a manual release test.


## Invite completion checkpoint — 2026-09-09

Independent code review reproduced a stale chat-list response undoing successful first-language setup. The revision guard now discards pre-save snapshots and fetches again without reopening setup. The regression failed before the fix and passes after. Added explicit checks for sharing failure/retry, dismissed-share token preservation, and failed next-link preparation followed by inline retry.

- [Focused checks](checks/2026-09-09-focused.txt): 78 passed.
- [Targeted analysis](checks/2026-09-09-analysis.txt): no issues.
- [Android compilation](checks/2026-09-09-android.txt): succeeded; installed and launched on `emulator-5554`.
- [Setup race before fix](checks/2026-09-09-setup-race-red.txt) and [targeted repaired checks](checks/2026-09-09-retry-green.txt).
- Local backend is unavailable: Docker status/container queries time out and localhost API refuses connection. A requested Docker Desktop restart did not recover it during the pass. Cached Chats remains usable with the standard No connection banner; no fresh database integration or online two-device result is claimed.
- No hosted migrations applied. The emulator package targets local QA, not production, and must not be handed to the owner as a working remote-phone release.
- Remaining owner setup: identify two Android phones, the installed app version, and the matching reachable test environment before walking through Copy/share/join/retry. Public signing and store installation remain separate release gates.
