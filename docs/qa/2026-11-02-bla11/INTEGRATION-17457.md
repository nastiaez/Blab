# BLA-11 approved integration · 17457 · 2 November 2026

Nastia approved the inspected header and corrected menu in Telegram topic14166/message17457, including visible word-internal wrapping in the localized long language value. Commit/main integration and integrated Android verification authorized. The initial distribution hold was superseded by Nastia17472: finish combined checks and release BLA11+BLA40 together to existing testers; public release remains separate. Only Blab-test Android Firebase delivery was performed in this continuation. Public flavor, iOS/TestFlight and public stores remain unchanged; this is not an all-platform rollout-complete claim. No custom release notes, tester emails or messages were authored.

## Exact scope and reconciliation
Fresh `integrate/bla11-approved-17457` in `../blab-bla11-integrate-17457` from fetched main `eb418e190d42d303937cbfa0d7a9e8ca377e1b27`. Original dirty candidate `feat/bla11-header-20261102` at `ed2ac549d287944613341491eaf700299aaf8a38` preserved. Only the reviewed four header/menu source files, their regression tests and isolated native fixture were ported. Patch applies without textual conflicts; current-main BLA-40 import and all its other files retained. No backend/schema/preference adapter changes. Unrelated generated early-opening parity output, raw media/logs and stale progress text excluded.

Presentation: existing muted typing #5F6770; 14px untruncated content-fitting mode label; scalable capsule with 48px minimum action target; 48px overflow; responsive second row; finite menu width and naturally wrapping rows. Existing callbacks, assets, mode meanings, language ownership, current-main mentions/name-conflict/deleted-account behavior preserved.

## Reviewed source fingerprints
- chat_menu.dart SHA256 `384d138165d18386ec6912a5b7bb644870fc29d1728344756a3412646216249b`
- chat_header.dart SHA256 `566bb9c5039c9494e9a9d5dd436e4471dc7e4a9dd907fdf804b5ef550cc17b3a`
- chat_mode_toggle.dart SHA256 `f72648fd0625f9f9afd5124b90aa4679479bbb8246aded6dbc5acc97f25b589f`
- integration_test/bla11_header_native_test.dart SHA256 `546ec46c29b678d51a109dbd77011e62bb742bfc023f7a33ab54a4d4f994e7de`

Approved corrected packet remains `/Users/aswin/.openclaw/media/blab-bla11-menu-17430/`. Actual 17.267s native-menu-review.mp4 SHA256 `ebd0a43f14c9ebad30a41546740f24487fc7604b5674717340aa549971805ad6`; uk200% overflow `7dff4981e468e918b22d0199bb5eb6b07e36c1f907b92723701745e3cbd54104`; es200% overflow `c91e4c56b1058d60031fdf9799b9e456194370d3333c746cd51c0fd0b2fce3b4`. Earlier clipping captures are not corrected proof. Detailed historical QA stays in the preserved original candidate docs/qa/2026-11-02-bla11/.

## Verification status
Fresh exact-current-main automated and integrated native gates are retained in `../qa-runtime/bla11-integration-17457/`; historical1186/17 results were not reused as proof of this reconciled source. Independent read-only review found no concrete semantic regression: names/deleted accounts/mentions, BLA40 links, existing mode callbacks/persistence and language-preference ownership preserved.

Fresh reconciled gates: full Flutter coverage suite **1200 passed / 17 environment-gated skipped / 0 failed** (1m58s), analysis clean, Dart formatting416 files unchanged, pure Deno224 passed/0 failed, shell syntax and whitespace clean. Focused combined header/menu/mode/ChatScreen/link161 passed. Full CI41506355398 on the feature revision and main CI41509026870 both passed all3 jobs: Quality, disposable Supabase integration/authority, Android release compile. No PR/protection bypass (main protected=false; rulesets=[]).

## Integration and native proof
Feature71ee3b6e061b1403c0575ee0097ef3040017e010 fast-forwarded onto clean main and pushed; local main/origin/main/live remote equality and BLA40 commit191933a ancestry verified. No textual conflicts. This final receipt is documentation-only beyond that exact built/tested application revision.

After main synchronization, integrated native fixture on exclusively leased existing bob/emulator5584 passed Ukrainian/Spanish ×100/200%: effective14/28px label scale, fixed avatar,48px target/semantics, toggle, two menu callbacks and dismissal. Clean teardown1m13s. All12 fresh native images opened/inspected; no material visual difference from the approved packet, complete bounded wraps including accepted word splits. Actual67.393s screenrecord retained, not constructed UI. Source hashes above unchanged. Isolated .bla11qa package only for fixture; temporary Firebase-plugin/applicationId edits restored byte-for-byte before signed build. No backend/schema/data fixture mutation.

## Signed test49 delivery
- Exact integrated source71ee3b6; package blab.nastia.ez.test;1.0.0(49);88,310,862 bytes. Version49 avoids the historical held47/48 duplicates; previous live Firebase45 and installed45 verified.
- APK SHA256 `7a91e657bef678dc4f6686c964c74d43d1c21624139309a47dece36493e6342a`. Certificate SHA256 `1a18ccd503847eb3eda9f423405ef46740424bc32bb850f1795a9922b27c0ffb` matches existing signing identity. Explicit staging config/backend parity verified.
- Replacement install45→49 only. Five settled preference XML hashes identical before first launch; original firstInstallTime2026-10-29 14:52:34 retained. Updated app PID/foreground verified; inspected English Welcome identical to existing predecessor baseline, not an onboarding reset. No signed-in account/history baseline existed, so account/chat retention is not claimed.
- Existing Firebase app1:1084218779858:android:82904f8d21106e4911250b / blab-staging. CLI account403, recovered through already-authorized console without new resources/login. Firebase release `19uldij5elg80`, distributed to the exact same13 email identities as current45;4 accepted,0 tester downloads at readback. No new tester audience/automated tester, no custom notification text.
- Firebase Copy generated: https://appdistribution.firebase.google.com/testerapps/1:1084218779858:android:82904f8d21106e4911250b/releases/19uldij5elg80 . Exact release reopened and testers verified. Browser Download saved bytes to /tmp/openclaw/downloads/Blab-test-49-71ee3b6.apk; SHA256 and byte comparison match the tested APK. This is admin download-back proof, not a tester installation claim.
- Only staging test/android update notice advanced45→49 after distribution; destination unchanged and other3 rows exactly unchanged.4 focused update-notice tests pass (older-build eligibility/current-build exclusion/destination scoping/disabled-failure behavior/layout). Other platforms not advertised.

## Preserved boundaries and resources
iOS simulator inventory inspected: none booted. Host free space fell from9.2GiB to about1.8GiB after native/signed builds; no further cleanup authorized or performed, no extra simulator/build launched. iOS, physical device, TalkBack spoken focus-order exploration, live two-account/provider and preference destination/persistence remain unverified. Native semantics assertions are not TalkBack listening proof. Public flavor not built/distributed and production backend untouched.

Existing bob5584 gracefully stopped; display780x1688/density320 unchanged from observed startup; packages/data preserved.5586 became active under another owner and was never touched. No AVD creation/reset/deletion or theft. Leases released after final receipts. Original dirty candidate and unrelated generated parity evidence preserved.

Private artifact/notice receipts: ../releases/20261102-bla11-bla40-17472/. Fresh inspected delivery PNGs: /Users/aswin/.openclaw/media/blab-bla11-integrated-17457/. Earlier failed shell baseline/hash or immediate-PID probes are rejected attempts, not successful evidence; final settled files and ready-state capture are canonical.
