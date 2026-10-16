# Chat lifecycle slice

Owner13655 authorizes implementation and requested launch, subject to existing actual-screenshot review gate. Base8f94aa8; dedicated branch feat/chat-leave-delete-20261016.

## Behavior and dependencies

Leave closes the chat for both, preserves readable history and displays Left chat. Reinvite creates a fresh chat ID only after closure; active pair deduplication and all user blocks remain enforced. Current canonical pair unique constraint must become an active-pair partial unique index. Invite notification identity must include the new chat ID so a repeat recipient gets the new connection event without duplicate notifications for repeated joins.

Owner clarified: Delete is viewer-only and new incoming messages bring it back. Keep a personal history cutoff; do not restore cleared messages. Accepting a new invitation after a personal deletion starts a fresh conversation for both, without erasing the other person’s old conversation. Leaving fences new authorizations; already-authorized in-flight vendor work may reconcile into the retained history without reopening messaging.

## Preference boundary

No translation-policy, generation, checker or cache ownership change. Retained messages use each viewer's historical Learning Language and Primary Known Language; Interface Language owns new labels/dialogs only. Fresh chat gets independent required language setup, rather than reusing the ended chat's settings. Closed chats retain word help/copy/listen/report access; messaging must be denied by the server, not merely by hiding the composer. Test asymmetric preferences and unchanged old history.

## Verification plan

Nonmember denial, idempotent leave, both viewers terminal, stale/offline send denial, Stream command/media reservations, legacy direct-send path, pending command race, preserved block behavior, repeated/parallel invite joins, distinct new chat and no old history carryover. Native leave/profile/composer states, swipe cancellation/confirm/error, relaunch/cache persistence, both platforms, all four interface locales and large text.


## Evidence so far (uncommitted candidate)

- Flutter full suite before final closed-header typing guard and lint-only brace adjustment:967 passed,15 local-backend integration cases skipped by the normal test runner. Retained `/tmp/blab-lifecycle-all-tests.log`; no claim that the skipped cases ran.
- Analyzer: no issues; formatting and diff whitespace checks pass.
- Stream-focused Deno checks:30 passed.
-104 migrations apply in isolated PGlite with Supabase auth/storage/realtime/scheduling environment stubs. Seeded Alice/Bob/Carol tests pass: chat_lifecycle, reusable_invites, single_call_batches, test_app_boundary, translation_storage_acceptance. New lifecycle checks cover viewer-only delete, old-event rejection, genuinely new incoming restoration, personal-history RLS, partner history, outsider denial, idempotent leave, both memberships/clients' rows closed, stale direct sends, Stream sends/uploads, forged lifecycle changes and fresh reinvite/dedupe. This proves SQL authority/RLS against the harness, not hosted Supabase or concurrent vendor requests.
- Android emulator5566 native production-widget journey passes cancel/confirm Leave, retained history/terminal composer, list state and cancel/confirm swipe Delete. Screenshots saved outside repository in `projects/blab/qa-artifacts/chat-lifecycle-native/android`. This native service fixture is not a live two-account backend journey.
- Initial Android motion recording rejected: Flutter screenshot surface conversion left the video showing the test-starting surface. Do not deliver it as gesture evidence.
- Docker daemon read times out; shared Docker services were not restarted or reset. Real local Alice/browser + Bob/emulator backend acceptance and concurrency checks remain unverified.
- iOS QA simulator booted; first dependency resolution exhausted available disk. Only this worktree's generated Android output and failed extraction staging were cleared. Reused APFS-cloned existing dependency cache with workspace paths corrected. Native iOS retry passed the same cancellation/confirmation/history/list/delete journey. All seven native screenshots inspected. Existing language-flag emoji render as missing glyphs on the iOS simulator profile; no claim of full-profile visual parity or live provider output. Lifecycle controls and dialogs have no clipping. First recording was invalid after disk exhaustion; recapturing from the exact prebuilt test app.
- No commit/push/merge or deployment. Owner screenshot approval is required before commit/push and integration; live backend checks must pass before release. Physical owner/manual tracker remains unchecked.


## Owner review packet

Android:01 Safety action,02 Leave confirmation,03 retained history with Left chat,05 swipe Delete confirmation. iOS:03 retained history,05 swipe Delete confirmation,06 resulting Chats empty state, plus gesture recording once validated. Synthetic Alice interfaceEnglish/Primary KnownUkrainian/LearningGerman and partnerBob learningEnglish are rendering fixtures only; SQL independently checks both seeded identities. No new paid translation calls, remote chat fixtures, history rewrites or production writes.


Final focused regression:91 passed after final header/queue guard; analyzer clean. Both native journeys passed, including a repeat iOS run of the exact prebuilt test binary. Valid50.5s iOS source recording inspected by extracted frames; review4.5s swipe/cancel/confirm-delete excerpt16.5–21s excludes fixture-host resets and startup. No motion reconstruction or screenshot animation. Canonical logs retained beside native artifacts. Final focused rerun initially exhausted disk; cleared only this worktree's generated simulator app/build output, then rerun passed. Installed test apps and dependency cache retained.


Review packet delivered in current topic: screenshots13665–13671, video13672. Await owner approval of visuals/workflow; explicit launch intent remains recorded, but is not approval of unseen screens. No commit, push or release. Retained dependency cache and native installed apps; discarded only generated worktree build output to recover space.

Owner13674 approves the delivered native visuals/workflow (screens13665–13671, motion13672). Continue clean backend checks, integration and the previously requested Android/iOS launch. Owner manual-device tracker remains unchecked; screenshot approval is not a physical-device test.

Clean runner38932591319: new real authenticated client lifecycle test passes; backend suite detected the old push integration assertion still querying token:recipient instead of token:recipient:chat. Updated the exact outbox-key assertion (including chat ID) and added distinct old/new-chat notification assertions plus repeated-join deduplication. No app/backend behavior changed by this follow-up; full rerun required before integration.

Incoming-during-delete regression: synthetic service returns the newly restored active chat before deletion completes. Red test lost the visible row; changed confirmation to dismiss only if the refreshed list still excludes it. Green: all6 lifecycle cases pass, including incoming restoration and four-locale large-text dialogs. No screen/copy redesign. Docker force restart explicitly approved in-topic and daemon recovered without reset or deleting containers/volumes; isolated task stack being prepared.

## Approved integration and release preparation

- Source `c02857f00ff6cc6f3392fa2d7c422fa014dd6988` passed all3 clean candidate checks in [38935694312](https://github.com/nastiaez/Blab/actions/runs/38935694312). Main was fast-forwarded and remote ancestry verified at that exact source. Integrated native Android journey passes, all7 captures inspected; stale integration-plugin registration required dependency resolution and a retry, not an app-source change.
- Task-owned disposable local Supabase `Blab_Lifecycle_20261016` on56321 rebuilt104 migrations. Alice/browser and Bob/Android5566 authenticated with repository local seed identities, identities confirmed in UI. Bob's profile completion was seeded locally; both interface/Primary Known English and selected Learning English, Normal mode for messages. Real UI sends both ways; personal delete clears only Bob, Alice retains history, a new incoming restores Bob with only new content, Leave closes both composers, same invite creates distinct empty chat. Canonical live manifest and screenshots retained in `qa-artifacts/chat-lifecycle-native`; delivered two-sided Left chat proof13684–13685. No hosted fixtures or paid-provider claims. Local legacy transport is live; Stream authority independently covered by database/Deno checks. One early rapid practice-setup attempt showed a deactivated-ancestor debug surface without retained stack; restart and two deliberate language confirmations succeeded. No established baseline/root cause or claim that this separate transient is fixed.
- Signed Android29 and iPhone29 prepared for test/public from integrated source. Package/bundle IDs and versions checked; Android predecessor signing certificate unchanged. Dedicated5574 signed28→29 replacement without uninstall/clear retains test German and public Spanish interface preferences. This is reconstructed signed-out emulator retention, not physical-device or signed-in-history acceptance.
- Staging migration04 and only `stream-channel` deployed; function source and SQL bodies verified against committed source. Production dry-run rolled back; no production writes/distribution. Staging Android29 release0khnj4ftddrb0 distributed to the same9 testers, reopened and verified; native browser download-back matches SHA256 `3b4b7f45ca3437a1bfe234ec9dd67091b95ae39c527aba3fdf90946d5e664077`. Staging iPhone29 valid, existing Owner testing and Invited friends groups assigned, Apple reviewAPPROVED and both testing statesIN_BETA_TESTING. Production requires final exact-scope confirmation under repository gate; all owner/manual tracker boxes remain unchecked.
- Full private receipts/artifacts under `releases/20261016-chat-lifecycle-29`; runtime artifact source remains c02857f even if later documentation-only records are added.

Integrated-main repeat CI [38937410976](https://github.com/nastiaez/Blab/actions/runs/38937410976) also passes all3 jobs at the same runtime source. Final production read-only check:103 migrations, lifecycle04 absent, no lifecycle column; production remains unchanged. Exact production proposal: migration20261016000004 + committed stream-channel source, signed public Android29 and iPhone29 to existing production audiences only; preserve environment secrets/access and all existing messages. Artifacts/hashes, approval, staging SQL/function parity, native/live proof, signed retention and delivery receipts are retained in the private release directory. Await final owner production confirmation; manual tracker remains unchecked.

## Production delivery complete — owner approval13688

Supersedes the pre-approval status above. Exact approved migration04 applied (ledger104); lifecycle SQL bodies match tested staging, deployed stream-channel/index.ts and shared stream_server.ts match committed hashes. JWT protection unchanged. Anonymous Leave/Delete/service requests return401. No production chat fixtures, message backfill or history rewrite; authenticated live-production two-person UI is not claimed.

Public Android29 distributed to the same2 production testers; exact release reopened and membership verified. Native browser download-back SHA256 `ca91ee0eac0f0e9ab7083a69535bd1994ed2f11f5d01459632582d363153766d` matches the signed APK installed in-place on5574. Public iPhone29 (`blab.nastia.ez`, IPA SHA256 `30ecd6e40b9981badaf9510219b7c0205242da24f3b208a03cff3db4e72cf1a6`) uploaded successfully, valid, notes saved and existing Owner testing group assigned. Exact group/build relationship and internal IN_BETA_TESTING read back. No new production external audience or public store publication. Staging remains available to its existing9 Android testers and both approved TestFlight groups.

Runtime artifact sourcec02857f; both candidate and integrated-main full CI successful. Release receipt, per-environment artifact mappings, signing/retention limits, authorization checks, source parity and delivery results retained privately under releases/20261016-chat-lifecycle-29. Owner physical-device acceptance is separate and pending; tracker checkboxes remain unchecked.
