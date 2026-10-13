# Material 3 migration — implementation and evidence ledger

Status: implementation/test review in progress; NOT owner-accepted, merged or released.
Baseline: acecd59061323e962a967639f960ae730a2488b8, branch feat/material3-migration.
Main and tester v13 remain unchanged. Source spec is on docs/material3-migration-spec.

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

## Runtime ownership / safe resume
Dedicated AVD blab_material3_20261013 at emulator-5556; unrelated emulator-5554 must not be touched.
Local backend project Blab_Material3_20261013 uses ports 54420–54429, inspector8183.
Existing Language_App backend was not reset/stopped. Temporary migration supabase/config.toml must be restored from /tmp/blab-material3-original-config.toml BEFORE committing, but ONLY AFTER stopping the owned Blab_Material3_20261013 backend while its project id is still configured.
Owned functions exec session65714; fake non-billable provider env supabase/.env.material3-local. Do not copy production provider keys into it.
Debug google-services.json is ignored/local; synthetic CI script refuses this file. Back up/restore around non-distributable compile; never distribute synthetic artifact.
Logs under /tmp/blab-material3-*. Raw local backend logs/status can include generated credentials: report only filtered summaries.

## Remaining acceptance gates
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
- Current candidate synthetic release AAB compiled successfully. Retained the original cupertino_icons dependency after release tree-shaking exposed an SDK font reference despite no direct app import; do not remove framework-needed assets based only on app source scans. Final compile repeats with baseline dependency intact.
- Owned functions/backend stopped safely; original supabase/config.toml restored. Existing unrelated backend remained healthy and untouched. Owned local data volume preserved for reproducible resume.
- Older root screenshots 01–18 and first native-back.mp4 are historical intermediate evidence, not final parity approval. Final comparison folder, incoming-share/reply evidence and native-back-complete-cancel.mp4 are current review evidence.
