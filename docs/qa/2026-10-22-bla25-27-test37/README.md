# BLA25/26/27 Android test37 build

Request15396 in topic7501 authorizes one combined Android test build; no Firebase upload/distribution, notice activation, hosted backend/public/iOS action.

## Reviewed scope
- BLA25 photo preview type:131fe27; actual native FCM payload shade/tap15350; entrypoint fixture +254 backend tests. Hosted source-to-device and Stream unverified.
- BLA26 source-language guard:aa0ce66; actual sender/receiver fixture15361; no prompt/cache policy change.
- BLA27 long bilingual reading:bed1d9c; actual screenshot15366/video15368 approved15374. Short-message placement preserved; long reading remains expanded through scrolling.
- Build request15396 covers combining the presented fixes. Only test-fixture/progress append conflicts; source app paths merge cleanly. No unrelated pending candidate included.

## Remaining verification
Combined1,041-client gate, analysis,254 backend, combined native fixture and signed staging test37 build/36→37 update. Report observed results in external release receipt; do not infer live photo behavior from APK installation. Signed release is built from synchronized integrated main, not a mutable topic checkout.

## Artifact-only boundary
The APK contains the two client fixes. The photo-notification change runs on the server, and is retained in integrated source but requires a separately authorized deployment to activate. No hosting service changed by a build request. Existing Blab-test36 synthetic DE/signed-out baseline retained for signed update testing; no physical-phone or authenticated account retention claim.
