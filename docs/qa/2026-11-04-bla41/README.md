# BLA-41 implementation 17867

Base: current origin/main 6e870b8. Branch feat/bla41-gestures-17867; dedicated checkout. No merge/release authorized before visual review.

## Preference mapping before edits
Interface language owns menu/toggle/error copy only. Practice uses the historical Learning Language for primary text and audio; Primary Known Language owns the secondary comprehension lane. Normal known-source text stays authored; unknown incoming source uses Primary Known Language and conditional Original. Learning-aids-off, unsupported sources, membership AI cutoff, correction eligibility, form/tone/script and cache/provider contracts remain unchanged. Existing code resolves this in ChatMessageRow, MessageBubble and resolveMessagePresentation; server cache interface slot is Primary Known Language, not UI locale.

## Interaction contract
Long press opens existing anchored panels on both platforms without expanding text. Translate first, existing translate-16 icon, reveals existing Practice comprehension lane and closes menu. Persistent per-message Show/Hide translation notice uses existing muted notice style. No control until requested. Normal Original remains exact authored text. Toggle visibility is local to this open chat/viewer/output variant, not synced or persisted across app restart (durability beyond this visit not specified).

Expansion anchors original text and grows down; preserve initially empty space above a short conversation, never fabricate message content. Existing double-heart/reply, read receipts, drafts and primary copy/audio behavior retained.

## Evidence
- Full Flutter suite: 1,252 passed / 17 skipped. Analysis clean. Translation-policy checks: 243 passed. Shell syntax and diff whitespace clean.
- Four controller cases preserve both target and earlier-row coordinates on expansion/collapse (3/12 rows, 80/700px extra height). Later rows shift only by the inserted height.
- Android shared emulator5588, isolated synthetic bundle `blab.nastia.ez.bla41qa`: 2 native incoming/outgoing journeys pass. Screenshot states initial/menu/expanded/hidden/reopened, recording captured and delivered in group17902/17903. Visually inspected the delivered three screenshots and 22-second recording (original text fixed, later messages repositioned).
- Native fixtures replace backend/cache/auth; this is UI/gesture/layout verification, not a live-backend integration claim. No live service/prompt changes.
- Android harness assertion result passed; its final cleanup attempted the default package after the temporary Gradle identity was restored. Uninstall returned DELETE_FAILED_INTERNAL_ERROR; no successful production package removal. Future native commands use `--keep-app-running`; build-only identity overrides are not shipped.
- iOS native verification underway on existing shared simulator with a separate synthetic bundle. Existing app/data preserved.
- Review still pending. No merge, push or release.


## Shared-notice revision after first preview
Nastia said the first preview looks good, then requested slightly larger text closer to the bubble, consistently across all below-message notices. Updated both notice primitives to14px/1.25,1px vertical padding; explicit gaps2px. Existing colours/weights/alignment retained.54 focused regressions pass and analysis clean after this cosmetic update. Initial full1252/17skip predates this refinement; not represented as a fresh full rerun.

Initial iOS two native translation scenarios passed. Screenshot inspection found missing reaction emoji; a standalone UIKit UILabel probe reproduces it, independently of Flutter/Blab (`ios/native-emoji-probe.png`). Matches https://github.com/flutter/flutter/issues/183828 . No physical iPhone connected; no font substitution or runtime reset. Initial iOS screenshot evidence is not final emoji visual approval.

Updated iOS build stopped as shared free disk fell below1GiB (observed354MiB, then310MiB). Only own driver/build processes stopped; no other builds/data touched, no cleanup. Resume revised native iOS check when adequate space is available. Temporary platform build overrides restored; no platform guard/identity changes in source diff.

Android v2 first launch accidentally used the default ID because the replacement did not match a conditional applicationId. Confirmed package firstInstallTime==lastUpdateTime12:05:25, meaning this was a fresh synthetic install, not overwrite of an existing package. Stopped and removed only that fresh synthetic package; existing test/notificationQA apps preserved. Corrected explicit isolated identity before the final rerun. No live backend initialization or account operations in fixtures.


### Final revised Android evidence
Incoming/outgoing translation journeys passed on Android after14px styling. Both shared-notice text assertions passed in native UI; the third test's screenshot API failed because surface conversion had reset between tests. Captured that exact still-rendered app state using adb instead (`android-v2/06-shared-notices.png`), inspected and delivered. Added the missing conversion for future runs, but did not rebuild solely for capture plumbing under disk pressure. Do not call this native test file all-green:2 UI journeys passed,1 capture-only failure. Product/widget54 regression checks and analysis are clean.

Revised screenshots17929 and motion17930 delivered in topic7420. Reviewed actual enlarged/closer translation, retained Show label, failed-send and unsupported notices, plus20-second recording. Initial overall approval does not approve this revised unseen styling automatically. Updated iOS rendering remains blocked by storage and its emoji visual sign-off by the confirmed simulator font fault. No merge/push/release. Shared devices released preserving existing data; iOS remains booted as found.


BLA-41 colour refinement · Nastia17954 ·4 November2026: Show/Hide translation now uses the existing theme primary action/accent colour instead of textMuted. This supersedes the muted-toggle requirement only. Preserve14px typography, spacing and alignment; retry errors remain red and informational notices retain their muted styling. Source changed; fresh Android/iOS visual verification is blocked by host storage (306MiB free). Earlier screenshots do not prove this colour revision. No merge/release.

## Continuation18001 · 4 November2026
Storage recovered to8.2GiB; no cleanup performed. Existing candidate reused, no new product change. Android current colour verification: all3native scenarios pass, including previously failing shared-notice screenshot capture;6focused controller/flow cases pass. Inspected current menu, expanded/hidden and error/information screenshots; 22s real-time incoming-flow excerpt delivered18023 and three images18019/18021/18022. Synthetic fixture UI only, not live provider/backend acceptance. Existing shared5588 leased, isolated bla41qa identity confirmed in native log; stopped/data preserved and temporary Gradle overrides restored.

The first resumed iOS attempt (ios-v3) failed the native environment guard then Flutter connected to a previous installed fixture. Its apparent pass is REJECTED as stale source evidence. Retained logs/video explicitly historical. Corrected synthetic-simulator-only validator override, restricted to bla41qa + iphonesimulator, used for fresh ios-v4 build; original validator restored after the run. No production identity/guard change belongs in candidate diff. iOS verification pending at this entry.


BLA-41 quieter colour revision · Nastia screenshot feedback during18001 continuation,4 November2026: orange attracts too much attention; use message-colour or an existing kit brown. Selected BlabColors.warmInk (#46281C), softer than bubbleInk (#231208), preserving stronger legibility than warmMuted. Show/Hide only; keep14px/medium weight/2px gap, red retries and muted non-action notices. This supersedes orange17954; new native previews require review.


Final continuation18001: warm-brown (#46281C) candidate verified on Android android-v4 and iOS ios-v5; all3native scenarios pass on each. Inspected expanded/hidden/shared-notice screenshots and recorded motion. Android screenshot18034/video18036 and iOS screenshot18039 delivered. Analysis clean;6focused controller/flow checks passed before colour-only refinement; no repeated full-suite claim. Old orange ios-v4 also passed but is superseded. iOS reaction emoji still missing (independent UIKit/simulator fault previously confirmed); complete reaction visual acceptance remains blocked, not silently waived. Synthetic UI/gesture evidence, not live-provider/physical-device verification. Temporary Android/native-validator overrides restored with zero platform/validator diff. Owned5588 and B15A31DB stopped, leases released, existing data preserved. No cleanup, commit, push, merge, release or backend change. Await revised visual review.
