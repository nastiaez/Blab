# Invite completion and owner handoff

**Goal:** Finish and preserve the current invite repair work, then verify the launch journey without treating local evidence as owner acceptance.

**Scope:** Continue Step 2.3b and the invite portion of Step 3.7. Approved product behavior is unchanged. The invite website is already live; app signing/store handoff is not verified.

## Priority order

1. [x] Review current repairs and run focused expiry, failure/retry, auth continuation, first-language, native-share and pair-reuse checks. Fix concrete findings with regression evidence.
2. [ ] Prepare the Android review version; record runnable local evidence and the exact outstanding owner/device matrix.
3. [x] Commit only the invite work and its supporting evidence/spec/tracker updates on `fix/invite-flow-verification`.
4. [x] Push that branch to the existing Blab GitHub repository and verify the remote commit. Do not merge unrelated work or apply hosted migrations as an implicit part of a source push.
5. [ ] Owner checks the current app version on two devices: native Copy, installed share targets, dismiss/return, recipient signup/login, first-language selection, messages in both directions, same-pair reuse, and failure/retry journeys. Start by identifying device/app versions and environment.
6. [ ] Verify the production domain association, actual store install/referrer delivery and signup-to-chat handoff once release prerequisites are ready.

The no-expiry rule is part of priority 1 (including a link older than 48 hours) and the final launch check. `progress.html` owner checkboxes stay unchecked until matching manual confirmation; saving/pushing source does not imply launch completion.

## Checkpoint results — 2026-09-09

Repair source committed and pushed as `9e66db4`. Focused checks: 78 pass; targeted analysis clean; Android compiled, installed, and rendered the offline invite screen. The new setup-refresh race regression was red before the guard and green afterward; independent review found no further priority issues. Priority 2 remains partly open: the local backend is unavailable and no current remotely usable owner test version/environment has been confirmed. The 7–8 September database/integration evidence remains historical. Owner/device/store checkboxes stay open.
