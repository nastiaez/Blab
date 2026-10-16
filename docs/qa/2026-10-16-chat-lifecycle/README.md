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
