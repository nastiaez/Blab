# Notification arrow/photos · implementation started ·24 October2026

Nastia15856/15857 approves Paper design15853/15854 and requests implementation.
Canonical Paper p-7-0 Android24S-0/iOS25P-0. Approval is design-only, not unseen
native screenshots, main integration, production/backend changes or release.
Branch feat/notification-arrow-photos-20261024, origin/main0944b43.

## Scope decision resolved15866

Nastia explicitly chose initials for notifications and noted photo selection
should be possible. Verified current Edit profile/Group info have BlabAvatar
initials only, no photo chooser or stored avatar fields. Recorded photo selection
separately in ../ideas/change-checklist.md; not silently added to this slice.

Android implementation: native FlutterPlugin registered with every engine,
MessagingStyle with sender Person metadata, long-lived shortcut, LocusId,
receiver/chat-namespaced ID and SELECT_NOTIFICATION routing payload.
Avatar initials and colors reuse BlabColors, drawn natively (not dart:ui, so no
background isolate font-engine dependency). Group title from account-scoped chat
cache; generic/localized fallback without identities when previews are false.
Native shortcut errors fall back to notification display; privacy removes its
shortcut; logout clears notifications and Blab dynamic/cached shortcuts.

Android white/transparent arrow small icon is the OS tintable notification role.
Android launcher assets intentionally reuse supplied orange-arrow candidate
artwork for this requested identity; source SVG/raster assets retained. No
separate launcher approval/main integration inferred. iOS artwork remains
unchanged in this candidate. No photo-selection screens, backend changes or
remote push dispatch.

## Platform requirements

Android conversation composition requires MessagingStyle, sender Person metadata,
valid long-lived conversation shortcut, correct tap/account routing and cleanup.
Native plugin registration must work in the background isolate, not Activity-only.
Legacy FCM notification payload is OS rendered; cannot claim changing local display
changes that remote path. Stream path currently gates local rendering separately.
Previews-off must omit people/group identity, photo and message, preserving locale.
iOS currently has no communication capability, intent enrichment or notification
service extension. Native incoming push integration and signing/device verification
are required, not generic image attachments. Exact OS-owned geometry is not fixed
by the Paper export. No hosted changes or real push dispatch in this task yet.

Official references inspected24 October:
https://developer.android.com/develop/ui/views/notifications/conversations
https://developer.apple.com/documentation/usernotifications/implementing-communication-notifications

## Current proof

Analysis clean;39 focused checks pass, including presentation privacy across4
locales, sender/group role separation, identity namespaces, method-channel
presentation, native-failure fallback, cleanup and existing push identity/taps.
Android debug fixture compiles. Installed on owned fresh Pixel7/API36 emulator5584
already used for this topic; no user accounts/tokens or live backend involved.
Native fixture prints all tests passed. Both dynamic shortcuts exist as long-lived;
dumpsys notification reports both shortcut IDs "found valid? true". Private
notification has no shortcut/person/large image and generic body.

Collapsed01 and final expanded02 actual native screenshots opened/inspected;
first expanded animation frame rejected and recaptured once settled. No clipping
or persistent overlap in final exports. Group shows WE, sender AL and authored
message; direct AL; hidden-preview case Blab/generic only. Native Android badge
is a system-tinted arrow, NOT the orange/ink badge in Paper. Do not claim colour
parity or native iOS proof. Delivered15875/15876 to original topic, captions
explicitly local sample notifications, not live incoming-delivery proof.

Full client suite:1072 passed,17 environment-gated skips. iOS communication implementation, FCM background/cold
rendering, actual notification/shortcut taps, cache-miss group identity,
physical devices and owner visual review remain unfinished. Existing OS-rendered
legacy FCM path only gets new small icon; it does NOT gain conversation avatars
from these local-display changes. No commit, main integration or distribution.

## Colour correction /native probe

User rejects blue/white badge relative to approved orange/ink. Service had no
notification color hint, so Android used system accent. Native diagnostic fixture
notification_color_probe_native_test.dart uses identical valid conversation
shortcuts/initials with two variants, both with orange#F88C5A notification color:
full-colour launcher mipmap vs proper transparent arrow small icon. Actual API36
result: full-colour image flattens to solid contrast-adjusted orange dot; arrow
remains legible as contrast-adjusted orange glyph on system badge background.
It does NOT become ink-on-orange as in Paper. Fixture passes; exported04 opened
and inspected, delivered15883. No application color change silently promoted.

Rechecked Android16-release Notification.java processSmallIconColor: modern-target
small icons are colorable, assigned getSmallIconColor contrast color regardless
of bitmap colour. ConversationLayout owns badge background/geometry. Source:
https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android16-release/core/java/android/app/Notification.java
https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android16-release/core/java/com/android/internal/widget/ConversationLayout.java

Earlier Paper orange/ink badge was conceptual, not verified native support; do
not claim it is reproduced. Await user's choice of native orange-arrow option
before treating this as a revised visual target. iOS is separate/unverified.

## Exact artwork route15909 ·24 October ·custom-content proof

Correction15885/15893/15905/15909: original orange/ink SVG is mandatory. Native
orange-tinted substitute is NOT approved. User explicitly requests another way,
including the custom-layout route discussed. Previous wait for orange-accent
approval is superseded; do not offer it as the accepted target.

Implemented isolated native showCustomProbe entry point plus RemoteViews compact/
expanded XML under packages/blab_conversations. Uses image bitmap in custom
content, not Notification.smallIcon. Original SVG path/stroke attributes compared
with verified attached SVG; match. Raster378px preserves source rounded corners,
transparency, orange#F88C5A and ink#181616. No recolouring, redrawing or circular
mask of that artwork. Avatar initials reuse existing native method/palette.
The app's normal incoming-push service is NOT switched to this diagnostic method.

Actual fixture notification_exact_icon_native_test compiles and passes on owned
Pixel7/API36 emulator5584; analysis clean. Case set direct, group, private generic.
Initial system auto-group summary05 has no custom image and is not proof of exact
artwork. Expanded app group reveals children06: direct/group custom badges show
orange/ink source intact; private generic child shows standalone full icon.
Child expanded07 and dark08 opened and inspected. Exact orange and ink pixel
values present in both06/08; no unreadable dark-mode text or clipped artwork.
Light06 and dark08 delivered15915/15916; explicitly local samples, not live push.
Native icon artwork goal demonstrated in notification content, NOT every OS slot.

Costs/limits: DecoratedCustomViewStyle rather than MessagingStyle; native
conversation-specific treatment/priority controls are not preserved by this
proof. Android owns header/status symbol, expand affordances and auto-group
summary. Header symbol is still system-tinted; summary may hide custom child
artwork until expansion. Compact content48dp limits avatar to44dp (expanded48dp);
small artwork19dp. This is a new appearance for owner review, not pixel parity
with the Paper native-template sketch. No claimed production-ready custom layout.

Read official Android custom-notification documentation: supported custom content
with mandatory system decorations on API31+. Telegram current source inspected:
separate notification small icon resource vs large/avatar bitmap and messaging
style; this does not establish its rendered appearance on every OEM/device.
https://developer.android.com/develop/ui/views/notifications/custom-notification
https://github.com/DrKLO/Telegram/blob/master/TMessagesProj/src/main/java/org/telegram/messenger/NotificationsController.java

Next after owner visual decision: integrate chosen custom presentation with
receiver/session/privacy/read cleanup, test taps and background/cold receipt,
long text/font scale/group summaries/other Android versions, then iOS separately.
1072 full checks/17 skips recorded before diagnostic-only custom additions;39
focused checks from prior local native implementation. Final integration gates
must use final chosen source. No merge/backend/Firebase/update-notice changes.

## Circle revision15948 ·24 October

Nastia says custom layout is okay and requests circular Blab notification icon.
Derived assets/icon/source/blab-icon-notification-circle.svg from supplied original
by changing only the outer clipping path to circle(cx189,cy189,r189). Original
SVG retained. Raster notification_badge_exact.png reused by diagnostic fixture;
no launcher artwork or Android native header/status symbol changed.
Original orange/ink unchanged; solid ink pixels compared at378px and all match
identical coordinates, proving no mark resizing or clipping. Android fixture
compiles. Actual circular screenshot review pending; no release authorization.

Circle verification: native fixture passes on API36; final screenshot09 opened
and inspected, showing circle in direct/group badges and private generic icon.
Arrow/colors retained without clipping; source-original ink-pixel parity check
passes. Sent to original topic; native incoming-push/iOS/release limits unchanged.

## Approved implementation/build15954

Nastia approves circle screenshot15950 and asks to build both Blab and Blab-test.
Approved native custom rendering is now the Android BlabLocalNotifications.show
path, with exact receiver/chat/message read-cancellation tags and bound tap payload.
Android local opens wired for warm/cold starts outside the Stream experiment.
Final account guard reruns after loading cached metadata/artwork; no stale-account
notification is shown. Offline private copy can use server interface-language
metadata when profile cache is cold; cached/server group titles are display-only.

Legacy OS-rendered remote notifications cannot become custom from client-only
changes. New additive migration registers an explicit Android custom capability.
Existing registration resets capability false (safe rollback); new wrapper opts
in only the caller's Android token. New send-push selects high-priority data-only
for opted-in Android chat messages; older apps, iOS and invite notices retain
legacy notification payloads. Preview-off custom payload omits sender/group/body
identities; group title only included with previews on. Missing capability RPC
falls back on PGRST202 only; other failures remain failures.

Migration tested in its own no-host-port postgres17 container with faithful
minimal auth/token prerequisites: active caller, private flags, downgrade reset,
iOS untouched, suspended/signed-out/anon rejection. PASS. This is not a complete
clean rebuild of all Supabase migrations or hosted rollout proof.
1,078 client checks pass/17 environment skips;256 backend checks/9 steps pass.
Native integration fixture now calls the normal production rendering function
for direct/group/private. Test-package fixture passes; native warm tap matches
receiver2222 and direct chat1111. Public-package fixture also passes; screenshot11 opened and inspected, with exact circular direct/group badges and generic private icon. Warm tap matches the same receiver/chat in both packages. Signed builds in progress.

Reserve Android40 for both packages; both39 artifacts remain immutable. No
backend deploy, Firebase upload/distribution or update-notice activation authorized
by this build-only request. Keep exact source/trace/artifact hashes in
../releases/20261024-circular-notifications40/. Complete full backend rebuild,
actual remote receipt, integrated-main/signed Android gates before distribution.

Packaging note: Flutter 3.44 release with --no-pub after explicit pub get kept
dev plugins in GeneratedPluginRegistrant while Gradle excluded them. Rebuilding
with normal release-mode pub resolution regenerated the correct registrant;
signed test40 succeeds. This was generated build state, not a source workaround.
Test40 package/version and existing signer verified; installed on owned offline
API36 emulator and real main onboarding opened (screenshot12 inspected).

Both signed Android40 candidates built successfully from this worktree.
Package IDs blab.nastia.ez.test and blab.nastia.ez verified, versionName1.0.0,
versionCode40, existing upload certificate SHA256
1a18ccd503847eb3eda9f423405ef46740424bc32bb850f1795a9922b27c0ffb.
Both installed and cold-opened actual main onboarding on owned offline API36
emulator5584; screenshots12/13 opened and inspected. Native notification
fixtures used same rendering source; live remote delivery, authenticated upgrade,
full backend rebuild and integrated-main release verification remain unproven.
No iOS build, hosted deployment, Firebase distribution or update activation.
