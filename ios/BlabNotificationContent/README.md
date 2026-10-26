# iOS notification review candidate — 26 October 2026

Base: origin/main 6eacf7ac56c1f19b95ccc99b97ddda9a46c65d78.
Dedicated branch: feat/ios-notifications-20261026.

## Native constraints

UNNotificationContentExtension supplies the expanded notification only. The compact banner, Notification Center row, app header/icon, timestamp, system privacy policy and gestures remain iOS-owned. This is not an Android RemoteViews equivalent. Communication intents can request a sender/conversation avatar in the compact layout, but do not grant arbitrary layout or an independent full-colour Blab badge. Changing the launcher to force the badge would violate this task's scope.

The candidate therefore preserves the exact supplied circular orange/ink PNG inside an expanded native notification. It deliberately does not substitute a tinted mark or claim identical compact Android presentation. Compact initials/communication intents are not implemented in this slice. No Paper screenshot is used as native proof.

## Integration boundary

The display-only content extension is embedded in Runner, category BLAB_MESSAGE_REVIEW_V1. It performs no requests, reads no shared storage or credentials, writes no history, and handles no routing. The Flutter local notification path registers/selects this category, adds display-only metadata to the existing receiver/chat payload and checks account continuity after cache reads. Previews-off local alert and payload omit identities/body. Local warm/cold taps join the existing authorization-checked app routing. No existing remote payload selects this category; legacy remote iOS and all Android delivery remain unchanged. This is a local-rendering review candidate, not a complete remote-delivery implementation.

Before activating this category for remote notifications, coordinate with the send-push owner: introduce an explicit versioned iOS capability (legacy tokens unchanged), preserve receiverId/chatId/messageId, and ensure previews-off APNs alert AND metadata omit sender/group/body identities at the server. The extension cannot sanitize the compact system alert; rendering generic expanded content does not make an unsafe APNs alert private. Add account/epoch fencing and logout cleanup for any future communication-intent donation or shared account metadata. Do not use metadata as authorization. Validate physical-device APNs receipt and authenticated warm/cold taps separately.

## Presentation/privacy

Only explicit previewsEnabled true plus a nonempty display identity enables initials. Missing/false consent uses generic localized text and the full mark. Group label and sender prefix are display metadata only. The fixture intentionally includes identities with previews disabled to test that the expanded view ignores them; production must not send those fields when disabled. Dynamic Type uses system fonts and multiline message text.

## Native fixture

scripts/ios-notification-review/setup.rb generates a small UIKit host embedding the exact same extension, avoiding Flutter/Pods and reducing disk consumption. App.swift posts real local UNNotifications to the simulator, not a reconstruction of Notification Center. ReviewTests.swift long-presses the real system notification banner. FullAppTests.swift exercises the installed Flutter app production renderer through the explicitly local review entrypoint; its six compact/expanded captures are the final packet. The inspected direct/group/private expanded screenshots prove native local rendering only, not APNs/FCM/live delivery, full Blab installation, device signing, account switching, or end-to-end routing.

No merge, push, release, production/backend change or launcher/photo-selection change is authorized by this candidate.
