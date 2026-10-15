# Android onboarding delivery verification — 2026-10-15

The approved native onboarding was integrated, but website downloads and Firebase still delivered test v22 / production v21. No new UI change was required.

## Verified release

- Signed Android test and production v24, client revision 169189422eb1e993e1e05b645cf31ad6d2c56cce.
- Installed with `adb install -r` over test v22 and production v21 on emulator-5560; no uninstall or data clear.
- Both variants passed illustrated welcome → animated learning demo → new sign-up. German interface setting remained selected. This does not independently prove retained signed-in accounts or chat history.
- Screenshots in this directory show both welcome/sign-up states and the populated learning demo. Initial animation frames are not final-state evidence.
- Website PR https://github.com/nastiaez/blab-landing/pull/5 merged; landing main d52411f serves v24 on both invite pages. All 13 website checks passed.
- Downloaded live APK bytes match the tested signed artifacts:
  - Test SHA256: 21bbb286f0ff83052bbf5c14f84f9abd502dd7d14c24bebc693c70630ea28359
  - Production SHA256: 223775db85016fd704beef6ae3ac968666a569466964df2d86faff0e813a2d6b
- Firebase App Distribution readback: test 1.0.0 (24), invited 8; production 1.0.0 (24), invited 2. These counts are distribution receipts, not successful tester installs.

## Downloads

- https://loveblab.com/downloads/Blab-test-1.0.0-24.apk
- https://loveblab.com/downloads/Blab-1.0.0-24.apk

Existing installations need an update; changing the website cannot replace an already installed APK. Install over the existing app. Existing signed-in users are not forced through onboarding.

## iOS boundary

Previously verified test and production TestFlight build 23 contain the approved onboarding. This Android distribution fix does not replace those builds or claim a fresh real-device iOS verification. External test beta review and remaining device checks are separate outstanding work.
