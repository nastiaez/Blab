# iOS notifications16093 — local review candidate

- Branch: feat/ios-notifications-20261026; base origin/main6eacf7ac56c1f19b95ccc99b97ddda9a46c65d78.
- Checkout: /Users/aswin/clawd/projects/blab/blab-ios-notifications-20261026.
- Uncommitted, unmerged, unreleased. Actual owner visual approval pending.
- Simulator: Blab iOS QA, B15A31DB-1DA2-4114-8FF5-D9D5C1D6D4DA, iOS26.3. Xcode SDK26.2.

## What is implemented

Runner embeds a real UNNotificationContentExtension. The production Flutter local notification renderer registers/selects its category, supplies display-only metadata, omits private identities/authored body when previews are off, and checks account continuity after loading local metadata. Native display uses exactly the original circular PNG (SHA2564a082efecdb94af114cd77b5b371b9677c29ec08cfd1d90e19228d53864d5750), the same six-colour UTF16-sum avatar palette and whitespace-free initial rule as Android. No tinted replacement, launcher or photo-selection changes.

FlutterAppDelegate is the standard UNUserNotificationCenter delegate so local foreground presentation and plugin callback forwarding work. Local iOS taps now join the same authorization-checked routing used by existing local Android taps; extra display metadata is not used as authority. Final account-guard suppression and previous-account route protection are covered by automated tests, not a live multi-account device claim.

## Actual screenshots — inspected, not reconstructed

The final packet is from installed Blab-test with all native Flutter plugins and the production BlabLocalNotifications.show function. The entrypoint integration_test/ios_notification_review.dart is explicitly a local scenario selector, not an authenticated conversation or live push source. Its DEBUG ribbon and fixture screen are deliberately visible behind the real iOS notification.

-10-full-app-direct-compact.png: genuine iOS compact banner, unchanged existing app icon.
-11-full-app-direct-expanded.png: genuine long-pressed notification; AL avatar + full-colour circle.
-12-full-app-group-compact.png: group title and Alice attribution in system banner.
-13-full-app-group-expanded.png: WE avatar + exact circle, group/sender/body.
-14-full-app-private-compact.png: generic Blab/new-message copy; no person/group/message identity.
-15-full-app-private-expanded.png: full mark and generic copy; no initials/identity.
-16-final-main-entry.png: final lib/main.dart build installed and launched after replacing the review-only entrypoint. Actual Welcome; not signed-in acceptance.

01–04 are earlier UIKit-only host evidence, not the final packet. Diagnostics and the blank earlier expanded capture were rejected and are not acceptance. The blank extension was traced to missing explicit UserNotificationsUI linkage; corrected and native screenshots rechecked. Initial delayed-Dart fixture failed because background execution was assumed; replaced by immediate foreground local delivery with proper delegate forwarding. Failed attempts remain failures, not APNs results.

## Verification

- PASS: full Flutter suite1081 checks,17 environment skips. Retained /tmp/blab-ios-full-tests.log; final summary in verification-summary.txt.
- PASS: full Flutter static analysis, no issues; /tmp/blab-ios-final-analysis.log.
- PASS:149 native Swift presentation/privacy/palette assertions (scripts/ios-notification-review/main.swift).
- PASS:3 new iOS local-payload/privacy/account checks; existing29 notification/account cases also pass, included in full suite.
- PASS: real native FullAppTests direct/group/private walkthrough3/3; results-full-app-immediate.xcresult and attachment-manifest.json retain source exports.
- PASS: actual lib/main.dart simulator build + install + launch; final build /tmp/blab-ios-final-main-build.log.
- PASS: exact fixture simulator build + install + native real notification captures; /tmp/blab-ios-fixture-immediate-build.log and /tmp/blab-ios-full-app-immediate.log.
- PASS: git diff --check; original artwork hash parity. Source fingerprints in source-sha256.txt.

Generated native apps are retained in build/ios-notification-review/NotificationFixture.app and build/ios/iphonesimulator/Runner.app (final main). Simulator was restored to final main, not left in the fixture. Extension bundle is blab.nastia.ez.test.NotificationContent and its version follows the containing app via generated build settings.

## Important proof boundaries / remaining gates

1. Compact geometry and icon are iOS-owned. The observed compact banner does NOT show the initial/avatar/arrow composition; that appears after long press. Communication-intent compact avatars are not implemented. No claim of identical Android compact appearance.
2. The reviewed notifications are real LOCAL notifications on a simulator. They are not simctl APNs injection, not APNs/FCM delivery, and not a live send from another account. No remote activation is implemented: current remote iOS payloads select no custom category and keep legacy delivery.
3. Remote activation needs coordination with the send-push owner: versioned opt-in/legacy compatibility, server previews-off omission from BOTH alert and metadata, receiver/account/epoch lifecycle handling, actual physical-device APNs receipt and authenticated warm/cold tap acceptance. No backend/send-push/schema/production mutation was made by this candidate.
4. Device signing/provisioning for the new extension, distribution, owner visual approval, lock-screen privacy settings, dark mode, large text/long-content stress and live account switching remain unverified. No release-readiness claim.
5. Android recovery/deployment, Docker lifecycle and shared Android emulators were not touched. No iOS commit/push/main integration, merge or release.

## Reproduction

Use the repository's staging setup (scripts/prepare_ios.py staging), then flutter build ios --simulator --debug --dart-define-from-file=env/staging.json. For the explicit local scenario entrypoint add --target=integration_test/ios_notification_review.dart. The native review project is generated by scripts/ios-notification-review/setup.rb using the installed CocoaPods xcodeproj Ruby gem. FullAppTests runs against an already-installed fixture app; ReviewTests runs the smaller standalone UIKit host. The latter is supplemental, not a replacement for the full-app rendering packet.

## Correction16123: compact10 rejected; expanded11/13/15 desired

See [communication investigation](communication-16123.md). Native communication candidate now proven in installed full Flutter app: inspected compact20/22/24 and expanded21/23/25,3/3 native walkthroughs. Initials/group/private mark work on first appearance, but the system adds the EXISTING HEDGEHOG APP ICON as a separate small badge. This remaining mismatch is rejected/not complete, not hidden or described as faithful. Official Apple HIG explicitly confirms that badge is the app icon. No independent badge setter or unapproved composite/tint/launcher replacement was used. Production delivery remains unchanged; review channel is local DEBUG-only. User decision about separately scoped app icon is needed before exact compact design can progress; physical-device signing/live APNs/account routing remain unverified.

## LATEST: user16171 · correct arrow in ALL six notification states

Icon alignment was explicitly authorized and implemented for iOS ONLY. See [final icon-alignment record](icon-alignment-16171.md). Current reviewed packet is40/41 direct compact/expanded,42/43 group,44/45 private. ALL SIX opened and inspected, no hedgehog remains. Compact uses new exact-arrow iOS rounded-square app badge; expanded keeps the accepted custom circular mark and initials role. Native3/3 +149 Swift assertions +3 payload/account checks pass; full analysis clean. Prior icon-choice blocker is superseded, not an outstanding permission question. Production/APNs/account integration and physical-device signing remain separate unverified gates. No Android/backend/merge/release changes.
