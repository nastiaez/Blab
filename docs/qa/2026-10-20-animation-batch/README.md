# Both reviewed animations ·20 October2026

- Request14478 approves logo14476 and requests both animations be built after verifying Reels-style hold. Fresh worktree from current origin/main161cf77; applied only current BLA-7 and BLA-24 source/test diffs. Uncommitted candidate, not main/released.
- Main application entrypoint built as Android profile/staging/test package, with explicit onboarding refresh preview flag. Existing matching staging Firebase configuration used; no services deployed. Artifact is a local profile candidate, NOT a signed-release delivery. Private artifact manifest path: qa-artifacts/2026-10-20-reviewed-animations/manifest.json under Blab workspace.
- Actual packaged main app Welcome→Get started→Learn in context exercised. Five-second real Android touch hold: two content captures two seconds apart are pixel-identical (status bars excluded); release advances to the next phase. Touch setting restored. Native screenshot/recording retained in android/. No fake service override for this app entry; this does not prove authenticated two-account behavior.
-19 focused checks pass; analysis clean. First full run980 passed/16 skips plus1 intentional outdated Learn screenshot baseline. Updated only learn-reduced-motion.png for requested regular-weight exquisite; other reference images unchanged. Clean full rerun981 passed/16 environment skips (`/tmp/blab-animation-batch-full-final.log`).
- Source preserves1.40s logo/solo a,13.75s reading cycle, normal exquisite. No commit, merge, backend changes or distribution; iOS acceptance pending.

## Approved integration14486

Committed04524dc and pushed main; signed Android production30 built from exact integrated source (no preview flag), same existing signer. Signed29→30 update preserves ES preference on emulator5554; no uninstall or clear. Integrated focused16 tests pass. Private release checkpoint and captures: `releases/20261020-reviewed-animations-30/` in parent workspace.

Deployment authorized, **not uploaded/distributed**: Firebase App Distribution403 across existing credentials/browser identities. Backend preflight additionally detects pending queued BLA-15 metadata migration20261017000001. No hosted migration/notice activation or iOS30 delivery. Earlier candidate-only statements above are historical and superseded for integration, not delivery.

## Deployment14522 ·20 October2026

Both signed Android30 variants are distributed to the existing Firebase audiences: public2/test9 (same test cohort as29). Readback APKs exactly match verified hashes. Public release4qnifti2o7d18; test release02uggk209pgpo. Source04524dc, runtime identical at docs-only maina210c45. Signed29→30 retains ES(public)/DE(test); exact signed hold frames match across2s and advance after release.

Metadata migration20261017000001 applied to both environments after rollback/permission assertions; all105 committed migration versions match, RLS on, anonymous reads200/writes401, authenticated writes denied. All notices disabled; no service deployment or user-chat mutation.

Public iOS30 uploadc2a0d8f9-4774-4c7e-aafb-13100656eab9 VALID and IN_BETA_TESTING in existing Owner testing group. Test iOS30 build133e2998-8e46-4c65-9a1b-5ffbbcc778e6 is VALID/nonexpired, assigned to existing Owner testing1 member and Invited friends13 members; internal/external IN_BETA_TESTING and beta review APPROVED. No public App Store submission. New iOS simulator attempt blocked by disk exhaustion; no physical-phone or new live two-account acceptance claimed. All private artifacts/receipts retained in parent workspace releases/20261020-reviewed-animations-30/. Earlier deployment-blocked statements above are superseded by these receipts.

Final private availability verified for every existing configured Firebase/TestFlight audience. Exact APK/IPA hashes, Apple group/build states and disabled-notice backend verification retained in `release-receipt.json`. This is distribution availability, not a physical-device install or public App Store release.
