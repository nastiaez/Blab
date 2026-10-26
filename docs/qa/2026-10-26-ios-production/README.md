# Production iOS communication delivery · request16208

Dedicated branch feat/ios-production-16208, fresh origin/main b06925e.
Approved visual basis f3fcb7c (40–45, approval16186); original candidate preserved.
No main integration, backend edit/deploy, upload, tester/audience change or outgoing notification.

## Source implementation

- Real release-enabled blab/communication bridge, replacing the DEBUG-only fixture.
- Embedded NotificationService + reviewed expanded NotificationContent targets.
- Shared account-only app-group snapshot: receiverId, random accountEpoch, preview consent,
  Interface Language. No tokens, credentials, history, images or authored messages persisted.
- Epoch rotates when identity or preview consent changes; sign-out clears identity before
  unregister/network waits. Local delivered/pending alerts and Siri donations are cleared.
- Native local and service rendering require current receiver + epoch + v1 capability.
  Expanded rendering independently rechecks account/consent rather than trusting the sender.
  Missing/locked container, stale identity or unknown capability fails closed to generic content.
- Service timeout/error returns sanitized generic content, never the original private payload.
  Local stale-account events are dropped. An NSE cannot promise suppression of the OS alert;
  stale remote alerts are generic/non-routable, so server dispatch fencing remains mandatory.
- Compact communication intent uses the reviewed initials/artwork renderer and real provided
  recipient metadata, not a hardcoded three-person fixture. Expanded layout/color/font/spacing
  and launcher artwork remain the approved source. No intentional UI redesign.
- Foreground FCM uses one native local path; automatic iOS foreground APNs presentation is off.
  iOS local taps join the existing authorization-checked warm/cold routing.

## EXACT backend contract for parent owner (not implemented/deployed here)

Authenticated RPC:
register_communication_ios_push_token(
 p_token text, p_previews_enabled boolean,
 p_account_epoch text, p_capability_version integer
)

v1 only; reject malformed/empty epoch and unsupported versions. Derive user from auth.uid(),
never a caller-selected user. Preserve existing token uniqueness/account ownership/epoch,
permission and erasure controls. Persist platform ios, ios presentation blab_communication_v1,
capability version1, device-supplied account epoch and preview consent on the token row.
Versioned state belongs to each installation/token, NOT a global profile flag.
Re-registration must atomically replace prior identity/epoch; unregister/erasure invalidates it.
Legacy registration must not accidentally inherit v1 capability. Sender claim and final dispatch
must recheck active token/account epoch, current membership/mute/authorization and preview consent.
No v1 payload to legacy tokens. Client fallback is ONLY PostgREST PGRST202 (RPC absent);
other errors remain errors and are not silently downgraded. Android RPC remains unchanged.

FCM/APNs v1 envelope, only after matching capability registration:
- aps.alert.title = Blab; aps.alert.body = localized generic new-message text ALWAYS.
- aps.mutable-content = 1; aps.category = BLAB_MESSAGE_V1; sound default.
- Never put sender/group/authored body in aps.alert or top-level FCM notification: NSE may
  not execute, may time out or be unable to read protected storage.
- data (FCM strings): type=chat_message, receiverId, chatId, messageId,
  iosPresentation=blab_communication_v1, accountEpoch=registered installation epoch,
  previewsEnabled=true/false, interfaceLanguage.
- Only with authoritative current preview consent: senderName, optional groupTitle,
  blabPreviewBody (authored preview), optional recipientCount (actual active group members
  excluding sender, integer string1..100). No hardcoded group size. No remote image downloads.
- With previews off omit senderName/groupTitle/blabPreviewBody/recipientCount entirely;
  both alert and metadata remain generic. Payload is a hint, never cache/history authority.
- Extension sanitizes both metadata and tap payload again and preserves receiver/chat route;
  it retains the gcm.message_id FCM transport marker without misclassifying remote deliveries
  as local flutter notifications.
  Physical-device foreground/background/terminated delivery and taps remain acceptance gates.

## Apple setup outcome

Existing App Store Connect credential used in place, never copied into source/logs.
Authenticated GET bundle IDs/capabilities/profiles succeeds. Authorized setup enabled APP_GROUPS
on both existing parent IDs and registered all four explicit extension IDs:
blab.nastia.ez.NotificationContent / NotificationService and
blab.nastia.ez.test.NotificationContent / NotificationService.

Apple v1 API rejects COMMUNICATION_NOTIFICATIONS as unsupported capabilityType (HTTP409),
not an app entitlement denial. App Groups identifiers/associations + communication entitlement
still require Developer portal/Xcode provisioning. Existing parent profiles now report INVALID
following capability change; they MUST be regenerated, not reused for a release.
No old signing profile files/certificates were overwritten or deleted. This is a new-signing
blocker, not evidence that existing distributed TestFlight builds stopped working.

Actual -allowProvisioningUpdates extension device build with existing ASC key attempted:
Authentication failed; No profiles for blab.nastia.ez.test.NotificationService.
No connected physical iPhone. Portal browser tab blab-ios-production-capabilities shows
Apple Sign In, not an authenticated developer session. No credential prompts submitted.

Minimum human action: sign in to Apple Developer (including 2FA) in that tab, or provide an
already-authenticated Xcode developer account. Then enable Communication Notifications for
both apps, create group.blab.nastia.ez.notifications and group.blab.nastia.ez.test.notifications,
associate each parent/content/service ID to its own group, and regenerate/install six matching
App Store profiles (plus development profiles if needed). Existing distribution cert remains.
After signing is repaired, parent owns integrated builds/TestFlight upload; physical iPhone
must verify real APNs compact/expanded/direct/group/private, consent/account changes and taps.
No fresh visual approval needed for unchanged approved40–45, but this code evidence is not
new native/physical-device APNs proof.

## Disk / verification boundary

Started with9.2GiB free; no full app/archive build. Standalone Swift API typechecking and small
policy executable plus Flutter tests only. Xcode package resolution briefly consumed3.2GiB;
removed ONLY this task's generated DerivedData SourcePackages cache after provisioning exited,
verified by its info.plist workspace path. Source/evidence/APKs/app data and other worktrees intact.
See verification.txt and retained safe logs. Parent is sole backend/main/deployment owner.

## Independent source review

Read-only review found two source blockers, both addressed before commit:
- Superseded native sync now throws/retries rather than legacy-registering; only PGRST202
  can downgrade. A dedicated regression asserts no RPC on null native capability.
- Preview changes are serialized; failed/ambiguous server responses rotate native consent
  back before UI/persisted rollback, fenced to the same current account. Regression simulates
  server registration committed then response failure while enabling previously-off previews.
No reviewer-requested UI redesign. Signing/APNs/device gates remain open.
