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

## Build result15396

Integrated application source431495a on synchronized main.1,041 client checks pass/16 environment skips;254 backend checks/8 steps pass; analysis clean. Combined actual Android cached correction and long-reading journeys pass; all six captures inspected. Signed staging/test Android37 APK built from main, package blab.nastia.ez.test/version1.0.0. SHA256 `e8e5629e28f88c9a7ca49703948bc05471707c29270ade46d5d9a9507de0de52`; unchanged signer `1a18ccd503847eb3eda9f423405ef46740424bc32bb850f1795a9922b27c0ffb`.

Exact signed36→37 replacement installation on owned5580 passes; firstInstallTime and existing German signed-out Welcome retained. No authenticated/physical-device/iOS acceptance. Artifact and complete receipt: parent releases/20261022-bla25-27-test37/. Not uploaded/distributed, no hosted server/public app/update notice change. Photo fix is not activated by this APK; live server rollout remains separate.
