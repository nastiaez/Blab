# BLA-38 · notification icon investigation · 3 November 2026

Request: topic7420/message17665, explicit work on BLA-38 overrides Backlog queue filtering. Base origin/main d9e9474c3f2b350e4f06c85d3a66abeb92ff9427; dedicated fix/bla38-notification-icon-17665.

## Finding
The normal Android path in BlabLocalNotifications.show invokes showCustom. BlabConversationsPlugin uses Notification.DecoratedCustomViewStyle with custom compact/expanded content. Both XML layouts contain only avatar + bottom-right badge + title/body. There is no extra standalone app icon in custom content. The leading app icon belongs to the mandatory system decoration.

Android documentation explicitly says apps targeting API31+ cannot use fully custom notifications; removing setStyle does not remove system decoration. Do not downgrade target SDK, hide the required small icon, use transparent-icon tricks, or claim a one-line removal solves this.

Sources checked this turn:
- https://developer.android.com/develop/ui/views/notifications/custom-notification
- https://developer.android.com/develop/ui/views/notifications/conversations

Native MessagingStyle with a valid long-lived shortcut is the supported conversation presentation alternative. Its avatar/badge geometry is system-owned. Retaining the exact custom orange/ink badge is not established; changing that visual contract requires a product choice and new native evidence. Current implementation/evidence preserves custom artwork intentionally. No runtime change made.

## Scope and verification boundary
Only Android presentation is relevant; iOS/backend/preferences/translation output/history/routing are unchanged. Preserve direct/group/private previews, receiver-bound taps, cancellation and account guards for any future implementation.

Both reusable Android device claims (5584/5586) are currently owned by another execution. Neither device nor its applications/data were changed. No new AVD created. Existing repository notification screenshot inspected for diagnosis only; it is not fresh BLA-38 acceptance evidence. No tests or new native proof claimed.

## Resume
Obtain product direction on native system-styled avatar badge versus retaining exact custom artwork, coordinate a reusable device lease, then prepare/verify the chosen candidate and deliver fresh actual notification-shade screenshots before integration/release. No commit, push, merge, deployment or distribution.

## Candidate17674 ·native layout exploration authorized
The above investigation is superseded only for implementation permission: user17674 explicitly approves exploring native conversation/system badge. Candidate now routes Android to native MessagingStyle with receiver/chat-scoped shortcut, separate group/sender fields, original per-message cancellation tags and tap payload. Hidden previews stay generic and remove matching shortcut. iOS/backend unchanged.

31focused checks, clean analysis,243backend checks pass. Isolated QA debug APK builds successfully, package blab.nastia.ez.notificationqa, min24/target36, SHA25634cb120cb251e5268d690fa35ae36e31f99362cb362d3d33ce0d3927ef0fcafc. Uses existing approved_notification_native_test fixture to invoke actual production notification function with synthetic direct/group/private data; not yet installed or run. QA build temporarily overrides application ID and disables Google-services plugin (no Firebase use), and restores original Gradle file in finally; source Gradle diff is empty. No existing apps overwritten.

First full suite:1203pass/17skip/1failure because concurrent contract test observed temporary QA packaging configuration. Restored-source12 contract tests pass; full final rerun started in /tmp/bla38-full-tests-final.log. Do not call first full run green.

Device owner handoff requested using sessions_send run8feacaf8-2e91-4f7c-91dc-ae0c02cb1342. Both resource leases remain untouched; no fresh screenshots/native acceptance yet. Await reply, acquire explicitly released device lease, grant notification permission only to isolated QA app, install/run fixture, inspect direct/group/private collapsed and expanded shade light/dark; verify notification dump/shortcut and tap. Then deliver actual sample-data screenshots in topic7420. No merge/release authorized.

Final restored-source full rerun PASS:1204 Flutter tests,17 environment-gated skips (full-final.log). Earlier QA-configuration overlap resolved; no runtime failure remains in automated checks. Native screenshot/tap acceptance still pending device handoff.

## Resume17687
User explicitly requests emulator test and screenshots. Exact prepared APK hash reverified unchanged. adb has no attached devices; both emulator resource leases still name17636 owner. Renewed handoff accepted/queued run2ee021c0-494a-4e2c-91e8-974208c0ca96; this does not establish release. No device started or modified while ownership is uncertain. Resume on owner response; native/privacy/tap evidence still outstanding.


## Native verification17702 ·3 November2026
Both original devices remained reserved by live17636 owner. Under AGENTS permitted concrete parallel-QA exception, created third **reusable** AVD blab_shared_3 (API36/Pixel7, port5588); total Blab AVD count3, no feature-specific device, no old data modified.26GiB free before creation. Acquired own resource-emulator-5588 lock.
Installed exact prepared APK hash34cb120cb251e5268d690fa35ae36e31f99362cb362d3d33ce0d3927ef0fcafc into isolated notificationqa package. Existing production notification fixture runs successfully. Actual system shade inspected: direct/group compact and expanded in light/dark; no extra leading app icon, one app badge on conversation avatar; group expanded sender avatar expected. Generic private compact/expanded conceals sender and body. Notification dump has valid direct/group shortcuts; private has none and no Secret person/message text.
All three real warm taps emitted correct receiver/chat identities in native/native.log. This verifies native tap dispatch, NOT authenticated chat destination/history or end-to-end remote push. Cold-start tap, physical phone, iOS and signed release unverified. No runtime modifications this continuation; previous automated gates retained, not rerun.
Evidence native/:03-light-expanded,05-dark-settled,06-dark-compact,07-light-compact,09-private-expanded PNGs inspected.01 blank and04 transition captures rejected, not delivered. Telegram screenshots17710/17711/17712 delivered to7420 (sample-data captions). No visual approval inferred. Device restored light mode and gracefully stopped, data retained; own lease released after shutdown verification. Existing5584/5586 reservations untouched. No commit/merge/release.

## Approval17733 ·3 November2026
Nastia explicitly approved screenshots17710–17712: “Yes looks great. Let's implement this”. Approved Android presentation is unchanged. Fresh31 notification/privacy/state and11 router/session regressions pass. Current main remains original d9e9474, no reconciliation drift. iOS/backend unchanged. Signed-in native destination and cold-start/live remote push remain unverified; no release/distribution authorized or claimed. Preserve existing native evidence and prior full1204/17skip,243backend passes for unchanged runtime. Preparing scoped commit and exact-source CI; integration status follows below.
