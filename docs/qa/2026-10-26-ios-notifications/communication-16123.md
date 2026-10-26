# Compact communication investigation · correction16123

HISTORICAL: icon-choice blocker superseded by explicit16171 authorization and implementation. Final inspected corrected packet40–45 is documented in icon-alignment-16171.md.

Owner rejected10 (ordinary compact hedgehog banner). Accepted expanded11/13/15 are the desired visual specification, not approval of the first-appearance banner. Preserve the expanded extension unchanged.

## Official API evidence

- https://developer.apple.com/documentation/usernotifications/implementing-communication-notifications
  Apple requires Communication Notifications capability, NSUserActivityTypes INSendMessageIntent, participant INPerson images, incoming INInteraction donation and UNNotificationContent.updating(from:). Group avatars use setImage(forParameterNamed: \.speakableGroupName); group donations require full recipients or accurate recipientCount. NSE is the incoming remote/background integration location.
- https://developer.apple.com/design/human-interface-guidelines/notifications
  Apple explicitly states: “The system automatically displays a large version of your app icon at the leading edge of each notification; in a communication notification, the system displays the sender’s contact image badged with a small version of your icon.”
- https://developer.apple.com/videos/play/wwdc2021/10091/
  Apple describes standardized communication title/subtitle and prominent avatars; this is not a custom compact canvas.

## Native experiments

communication-v2: intent/donation code built and3 native tests passed, but no supported activity/capability configuration; compact inspection showed ordinary app placeholder, NOT success.
communication-v5: explicit INSendMessageIntent activity and communication entitlement. Inspected real direct compact: AL avatar with system app-icon badge. Inspected private compact: exact fullcolour orange/ink circular PNG as primary image with system app-icon badge. Group fixture failed and requires corrected recipient metadata; no group success inferred.

These are local UIKit fixtures, not full Flutter or remote APNs proof. Actual full-app review bridge is under implementation in Runner/BlabCommunication.swift and the explicitly local integration_test entrypoint. No launcher changes, composite avatar/badge image, tint substitute, backend or remote activation.

## Product dependency demonstrated

The user-provided person/group image controls the large avatar. The independent small overlaid badge comes from the app icon, not the person image or content extension. Changing the app's actual icon would be a separately approved launcher change and still uses the system's app-icon mask. No supported independent full-colour circular badge image parameter is documented. Do not silently draw a composite avatar to imitate that badge; no such substitute was approved.

Physical-device entitlement provisioning/signing, APNs delivery and account lifecycle remain unverified. No service extension activated: with exact compact badge design unresolved, remote activation would not solve the system app-icon dependency and would require separately approved privacy/version/account-safe payload coordination.

Full-app initial v1/v3/v4 attempts failed banner lookup, despite successful native intent update/add. Diagnosed Flutter local notification delegate recognition: required exact NotificationId (capital N/I), presentBadge and presentation flags, not merely payload. Corrected bridge metadata for v5. This is retained failure history, not successful full-app evidence.

## Final inspected full-app local packet (communication-full-v5)

Actual installed Flutter Blab-test, native INSendMessageIntent composition, same unchanged expanded content extension. Native walkthrough3/3 passed. All six images opened and inspected:

-20-communication-full-app-direct-compact.png: AL avatar, Alice/body; **system hedgehog app-icon badge remains**.
-22-communication-full-app-group-compact.png: WE group avatar, Alice/title + Weekend plans/subtitle + authored preview; **system hedgehog badge remains**. Native group context confirmed with recipientCount2 for explicit three-person fixture.
-24-communication-full-app-private-compact.png: exact orange/ink supplied image as primary avatar, generic copy, **system hedgehog badge remains**. No person/group/authored text displayed or supplied in private review payload.
-21/23/25 expanded captures retain the accepted exact circle+initials/private design.

This demonstrates the remaining design blocker in the ACTUAL FULL APP, not just an iconless UIKit host. The caller uses an explicitly local, DEBUG-only review channel; existing production Flutter local renderer and remote delivery are NOT switched to intents. The communication adapter has fixture recipient-count/identifiers, not production sender-ID/recipient membership or account lifecycle integration. Do not promote this fixture API to production as-is.

The three original iOS payload/account regression checks pass; full Flutter analysis clean. Earlier1081/17 Flutter and149 Swift checks are prior baseline verification, not newly rerun counts for this correction. Captured binary retained at build/ios-notification-review/CommunicationFixture.app; native results at build/ios-notification-review/communication-full-v5.xcresult. Foreground plugin compatibility is implemented with exact NotificationId/presentation metadata.

After screenshots, review channel was restricted to DEBUG and private image-missing fallback hardened to never generate initials. These safety-only source changes require final source build verification; they do not authorize a new visual claim.

## Minimal owner choice

Keep the observed native avatar layout and approve a separately scoped app-icon alignment (system mask still applies), or retain the current app icon badge and accept that compact differs from the expanded exact-circle composition. Exact independent circular badge matching is NOT achieved; no launcher change or composite substitute was made. The orange circle can be the main private avatar, but cannot independently replace the system app-icon overlay through the tested public communication API.

Final source normal lib/main.dart debug simulator build PASSED after DEBUG-only guard/private fallback hardening, installed and launched again (log /tmp/blab-communication-final-main.log). Main app restored, not left in review entrypoint.26-communication-final-main.png is final-source startup only, not authenticated account acceptance. Compact native3/3 captures are from the retained preceding review binary; safety-only source differences are disclosed above. No additional cleanup/deletions performed for this correction; free disk ~6GiB. Source/proof fingerprints recorded separately in communication-source-and-proof-sha256.txt.
