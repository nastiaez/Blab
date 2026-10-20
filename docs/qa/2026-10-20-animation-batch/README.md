# Both reviewed animations ·20 October2026

- Request14478 approves logo14476 and requests both animations be built after verifying Reels-style hold. Fresh worktree from current origin/main161cf77; applied only current BLA-7 and BLA-24 source/test diffs. Uncommitted candidate, not main/released.
- Main application entrypoint built as Android profile/staging/test package, with explicit onboarding refresh preview flag. Existing matching staging Firebase configuration used; no services deployed. Artifact is a local profile candidate, NOT a signed-release delivery. Private artifact manifest path: qa-artifacts/2026-10-20-reviewed-animations/manifest.json under Blab workspace.
- Actual packaged main app Welcome→Get started→Learn in context exercised. Five-second real Android touch hold: two content captures two seconds apart are pixel-identical (status bars excluded); release advances to the next phase. Touch setting restored. Native screenshot/recording retained in android/. No fake service override for this app entry; this does not prove authenticated two-account behavior.
-19 focused checks pass; analysis clean. First full run980 passed/16 skips plus1 intentional outdated Learn screenshot baseline. Updated only learn-reduced-motion.png for requested regular-weight exquisite; other reference images unchanged. Clean full rerun981 passed/16 environment skips (`/tmp/blab-animation-batch-full-final.log`).
- Source preserves1.40s logo/solo a,13.75s reading cycle, normal exquisite. No commit, merge, backend changes or distribution; iOS acceptance pending.

## Approved integration14486

Committed04524dc and pushed main; signed Android production30 built from exact integrated source (no preview flag), same existing signer. Signed29→30 update preserves ES preference on emulator5554; no uninstall or clear. Integrated focused16 tests pass. Private release checkpoint and captures: `releases/20261020-reviewed-animations-30/` in parent workspace.

Deployment authorized, **not uploaded/distributed**: Firebase App Distribution403 across existing credentials/browser identities. Backend preflight additionally detects pending queued BLA-15 metadata migration20261017000001. No hosted migration/notice activation or iOS30 delivery. Earlier candidate-only statements above are historical and superseded for integration, not delivery.
