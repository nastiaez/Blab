# Material 3 migration — implementation and evidence ledger

Status: reviewed visuals/journeys owner-approved, merged and distributed as signed v14; physical-phone acceptance remains separate.
Baseline: acecd59061323e962a967639f960ae730a2488b8, branch feat/material3-migration.
Application source e626fda is integrated into main and delivered in tester v14. Earlier entries below are chronological pre-approval evidence; final delivery supersedes their pending status.

## Implemented sections
- Semantic/component themes, shared Material bottom navigation/app bars/buttons/icon buttons/fields/password fields/auth-method actions.
- Shared account surfaces/ListTile rows/switches/selection rows/avatars/language chips and preserved per-surface variants.
- Supported modal/dialog/menu presentation; owner-requested exact custom Normal/Practice capsule (one shared Material focus/activation owner), route graph with real Chats parent for direct chat entry and guarded native Back.
- Chat presentation split into coherent part files with public view classes; existing lifecycle/state/translation algorithms remain owned by existing controllers/services.
- Workbench renders production shared/chat primitives via local fixtures, not duplicate preview renderers. Debug invite fixtures do not claim tokens.
- Unreachable placeholder/invite-language/exchange/subtitle renderers removed; live legacy auth/deep-link contracts retained.
- Tech spec corrected to actual Material/navigation and existing CI/private-delivery workflow.

## Observed verification (not a completion claim)
- Original baseline Flutter 821 passed, 15 environment-only skips.
- Intermediate full suite 817 passed, 15 skips (4 tests belonged only to removed unreachable subtitle renderer).
- Additional native semantics/header 320 width/all four locales/100–200% text checks pass; route graph menu-first/system Back regression passes.
- Selected native row/invite regressions 44 passed.
- Isolated backend: realtime readiness 1 and integration 11 passed; live provider cases 3 skipped intentionally.
- Backend unit tests: 136 passed, 0 failed.
- Latest full coverage: 832 passed, 15 environment-dependent skips; analyzer clean; formatting/whitespace/shell checks pass. Current debug Android APK built and installed; final CI/current release compile and device review remain pending.
- Two initial Android fixture screenshots delivered. They are review candidates, not approved visuals or production/model-quality proof.

## Runtime ownership / safe resume (backend now stopped; see final checks)
Dedicated AVD blab_material3_20261013 at emulator-5556; unrelated emulator-5554 must not be touched.
Local backend project Blab_Material3_20261013 uses ports 54420–54429, inspector8183.
Existing Language_App backend was not reset/stopped. Temporary migration supabase/config.toml must be restored from /tmp/blab-material3-original-config.toml BEFORE committing, but ONLY AFTER stopping the owned Blab_Material3_20261013 backend while its project id is still configured.
Owned functions exec session65714; fake non-billable provider env supabase/.env.material3-local. Do not copy production provider keys into it.
Debug google-services.json is ignored/local; synthetic CI script refuses this file. Back up/restore around non-distributable compile; never distribute synthetic artifact.
Logs under /tmp/blab-material3-*. Raw local backend logs/status can include generated credentials: report only filtered summaries.

## Pre-approval acceptance gates (historical; see final delivery)
- Final full checks and Android package compile.
- Latest candidate screenshots/recordings and same-viewport baseline comparisons.
- Complete affected journey matrix on Android, including predictive gesture completion/cancellation, keyboard/reply precedence, auth/selection persistence/media/native shares.
- Explicit owner acceptance of numbered screenshots AND journey behavior, especially native account-switch geometry exception and shared navigation border/shadow.
- Only then merge/synchronize main, sign/build from integrated main, verify update/session retention, distribute exact artifact to existing Firebase App Tester and download-back hash verify.

## Subsequent verification
- Final full coverage run: 828 passed, 15 environment-only skips (`/tmp/blab-material3-final-full2.log`).
- Android synthetic release AAB compile passed; non-distributable, not a tester artifact (`/tmp/blab-material3-ci-release.log`).
- Comparison restored 1-dp account card content inset; partner cards use explicit flush variant to preserve their existing DecoratedBox geometry.
- Latest safety/Profile focused suite: 23 passed; shared values/card/workbench suite: 14 passed. Full regression must repeat for these final cleanup changes.
- Main and actual remote ref verified unchanged at acecd59061323e962a967639f960ae730a2488b8.
- Real local app uses adb reverse tcp54321→owned host54421 to respect existing local config guard without changing it. Alice login/name/language setup works on Android. Dedicated Bob AVD emulator-5558 added for two-client checks; no emulator-5554 access.

## Owner-directed visual corrections (current candidate)
- Separate old/main and new/candidate captures are in `comparison/old` and `comparison/new`; manifests validate each screen before capture. Same Bob fixture, Android emulator-5558, 1080×2400, English, text scale 1.0.
- Both Normal and Practice capsule crops (580,150)-(960,260) have zero differing RGB pixels against baseline in these captures. This is evidence for those states/viewport only, not an all-state pixel-parity claim.
- Shared native NavigationBar now owns a foreground top border and warm upward shadow, used identically by Chats and Profile. Intentional new shadow and native equal-width destination positioning differ from historical custom navigation.
- Shared account rows restored regular-weight values and original inherited type metrics; selection sheet static region matches baseline. Native Material account switches still have different thumb/track geometry from old scaled Cupertino switches: explicitly pending visual acceptance.
- Old/new full chat images may differ in historical translation/pending layout or clock; compare fixed controls separately rather than interpreting dynamic-state changes as component drift.
- Latest used-invite deep link on updated Android candidate reaches existing chat without a restart workaround; cached onboarding destination invalidation has a new regression test.
- Completed/cancelled Android predictive Back gestures were recorded on owned emulator; fixture/widget tests additionally cover reply/menu-first Back, route parent, keyboard activation and disabled custom toggle.
- No main merge, signing or tester release has occurred. All acceptance checkboxes remain open pending owner journey review.

## Final local runtime/package checks
- Incoming Android ACTION_SEND image reaches recipient picker, dark preview and successful photo send on candidate. The shell-owned MediaStore fixture required media-read permission on the owned emulator; this is not a fresh physical-app URI-grant certification.
- Long-press Reply → compose literal O → send produced the correct quote; tapping the sent quote returned to the original Hello local message. Keyboard and quote screenshots were opened/inspected.
- Current candidate synthetic release AAB compiled successfully. Retained the original cupertino_icons dependency after release tree-shaking exposed an SDK font reference despite no direct app import; do not remove framework-needed assets based only on app source scans. Final compile with the baseline dependency intact passed; both font assets were retained/tree-shaken without the missing-font warning.
- Owned functions/backend stopped safely; original supabase/config.toml restored. Existing unrelated backend remained healthy and untouched. Owned local data volume preserved for reproducible resume.
- Older root screenshots 01–18 and first native-back.mp4 are historical intermediate evidence, not final parity approval. Final comparison folder, incoming-share/reply evidence and native-back-complete-cancel.mp4 are current review evidence.

## Final shared-chip correction
- Native Chip label alignment differed by one logical pixel from the original pill. Supported shared visual-density styling now restores the original center/height/inset; a geometry regression covers this contract.
- Final Profile capture was repeated and inspected. Chip-region mean absolute RGB difference is below 0.001/255 per channel (minor border rasterization only); both capsule crops remain identical for the reviewed default states.
- After this last source change: **833 Flutter tests passed, 15 environment-dependent skips**, analysis and formatting clean. Debug Android APK rebuilt and installed for the final capture.
- Earlier remote pinned-SDK Quality gate passed; final exact-head CI must include this correction. No main merge or release authorized/claimed.

## Approved integration and private delivery — 13 October 2026

- Ash explicitly approved the displayed screenshots/journeys and merge (topic message 12421). Reviewed application source `e626fdaf016dc50aa051643f721afbbfaef01b92` was fast-forwarded into main and pushed; local/remote main were verified identical and clean.
- Both final-revision and integrated-main CI passed all three jobs: Quality, disposable Supabase integration and non-distributable Android compile. Main evidence: https://github.com/nastiaez/Blab/actions/runs/38456762247 . Pinned Quality: 832 passed / 16 skipped (visual-capture case skips on CI); local: 833 / 15. Disposable readiness 1 + integration 11 passed; three live-provider cases deliberately skipped. Backend unit 136 passed locally.
- Signed **1.0.0 (14)** APK built from integrated main with the same hosted backend, Google/Firebase configuration, onboarding rollout and signing identity as v13. An obsolete local template Sentry setting was caught before upload; final artifact uses the exact original hosted setting recovered from the signed predecessor. No application source/config-validation guard was weakened.
- Certificate SHA-256: `1a18ccd503847eb3eda9f423405ef46740424bc32bb850f1795a9922b27c0ffb`.
- APK/download-back SHA-256: `4a6863677c5c1706acff646fb6dd276d9433003520b3b70211b10173ed59e005`.
- Existing Firebase project/app reused: `blab-nastia-ez`, `1:363935775546:android:c3a351249463d5f9356e03`. Release `77gcillcfljpo` distributed to the existing two approved testers; observed Invited 2 / Accepted 2 / Downloaded 0. No new tester, cloud project or automated testing agent was added.
- Dedicated emulator-5560: reconstructed baseline by installing archived signed v13 and selecting German through normal Welcome UI, then replacement-installed exact v14 without uninstall/data-clear. German persisted after cold launch; Welcome → Learn navigation inspected. This is a locale-retention signed emulator proof, **not authenticated history/account retention or physical-phone acceptance**.
- Private manifest, exact APK, download-back and before/after screenshots retained outside Git under the project's release/material3-migration-20261013 evidence directory. Physical App Tester installation and phone-only notification/identity checks remain separate acceptance states.
