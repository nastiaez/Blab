# iOS icon alignment · user16171 ·26 October2026

Explicit correction16171 authorizes replacing the old hedgehog iOS app-icon source in this candidate, so native notification badges use the supplied orange/ink Blab arrow. This supersedes the icon-choice blocker recorded for16123; no further permission question is needed for this scoped implementation. It is not merge/release approval.

## Exact source / isolation

Inspected original assets/icon/source/blab-icon.svg, generation script and1024 iOS rendered asset in separate blab-orange-launcher-icons-20261024 checkout. SVG has fill="none", orange#F88C5A rectangle and ink#181616 paths/strokes width27. Existing generator removes only pre-rounded background corners, leaving OS clipping; path geometry and stroke/fill treatment are preserved. Copied ONLY25 configured PNG files into this candidate's iOS/Runner/Assets.xcassets/AppIcon.appiconset. Contents.json was semantically identical and remains unchanged. No Android asset, shared launcher asset, pubspec change, branch merge or unrelated source copied. Snapshot of original SVG and per-slot SHA256 retained in16171-original-blab-icon.svg and16171-icon-provenance.txt.

The independent circular custom notification PNG and expanded extension are unchanged: SHA2564a082efecdb94af114cd77b5b371b9677c29ec08cfd1d90e19228d53864d5750. Initials remain the person/group avatar; orange/ink mark remains the brand badge. Compact badge shape/mask remains iOS-owned; do not describe it as the exact expanded circle without actual proof.

## Proof boundaries

Actual full Flutter simulator app, explicitly local DEBUG communication fixture. This is native composition proof, not APNs/FCM delivery, production remote activation, physical-device signing, account lifecycle or authenticated tap acceptance. Existing production local renderer/remote delivery remains unchanged. No backend, Android, release or merge action. Source/evidence/APKs/app data preserved; no cleanup required (5.7GiB free before build).

Initial corrected-icon build compiled, but native walkthrough found MissingPluginException: the new Swift DEBUG isolation lacked an active DEBUG compilation condition in this Flutter/Xcode project. That attempt is rejected, not screenshot evidence. Added inherited+DEBUG only to Runner Debug configurations; release/profile conditions untouched. Retesting exact final source.25 copied catalog slots pass dimensions against Contents.json.

V2 native3/3 assertions passed, but visual inspection REJECTED30–35: compact still showed cached hedgehog badge. The built Runner.app/AppIcon60x60@2x.png was opened and confirmed to be the correct orange/ink arrow; copied source alone is not acceptance. Restarting only dedicated simulator B15A31DB-1DA2-4114-8FF5-D9D5C1D6D4DA (shutdown/boot, no erase/uninstall/app-data deletion) then repeating native walkthrough. Do not deliver30–35 as corrected proof.

## FINAL PASS · inspected40–45 · communication-16171-v3

After dedicated simulator shutdown/boot (data preserved),3/3 native full-app scenarios passed and ALL SIX images were individually opened and inspected. No hedgehog appears anywhere in these notifications:

-40-16171-full-app-direct-compact.png: AL initials + NEW orange/ink arrow app-icon badge.
-41-16171-full-app-direct-expanded.png: accepted AL + exact circular orange mark layout preserved.
-42-16171-full-app-group-compact.png: WE initials + NEW orange/ink arrow app-icon badge; Alice/Weekend plans/body.
-43-16171-full-app-group-expanded.png: accepted group hierarchy/WE/circular mark preserved.
-44-16171-full-app-private-compact.png: exact circular mark as main image + NEW orange/ink app-icon badge; generic Blab/new-message copy; no identity.
-45-16171-full-app-private-expanded.png: exact private orange circle + generic copy; no initials/identity.

Compact small app badge is visibly the native rounded-square icon, NOT the custom expanded circular badge. Artwork is the exact original arrow, not a tinted or composited substitute. This fulfills new-artwork/no-hedgehog local composition review, without claiming identical system geometry or production/live acceptance.

PASS149 native privacy/presentation assertions,3 client payload/account regressions, full Flutter analysis clean,25 icon-slot dimension checks, git diff --check. Native result bundle build/ios-notification-review/communication-16171-v3.xcresult; corrected full Flutter fixture retained at build/ios-notification-review/CommunicationFixture16171.app. Previous30–35 are rejected cache diagnostics and MUST NOT be delivered as final.40–45 supersede20–25 as the current review packet. Old product-choice blocker is resolved by16171; do not ask again about implementing this candidate's iOS icon alignment.

Final same-source normal lib/main.dart debug build PASSED, installed/launched after retaining corrected fixture.46-16171-final-main.png opened/inspected: actual Welcome, not authenticated acceptance. Simulator left on normal app, not fixture. /tmp/blab-ios-16171-final-main.log retained. Current free disk6.4GiB; no generated cleanup/deletion performed. Candidate remains uncommitted/unmerged/unreleased; no native build/test job left running.

## Approval16186 · integration scope and executed signing blocker

User approved corrected40–45 visuals and requested conflict check/commit/main/deploy. Fetched origin/main remains6eacf7a, equal to candidate base, so no textual divergence. Semantic audit: review DEBUG adapter uses fixture membership/count and is NOT production sender/account/remote capability/NSE integration; do not represent it as completed push feature.

Executed real iphoneos Release extension build (without online provisioning mutations): fails “No profiles for 'blab.nastia.ez.test.NotificationContent' were found”; Xcode cannot locate required matching development profile and automatic profile generation is disabled. Existing parent App Store profile Blab Test App Store does not provision this new extension identity. xcrun devicectl list devices: no devices found. No physical APNs, account switching or signed extension acceptance available. No -allowProvisioningUpdates, bundle registration or hosted mutation performed.

Existing private iOS destination is TestFlight: regular app6823314008 and test6823316052; coordinator record says latest accepted delivery30. User16186 does not authorize a new TestFlight/App Store publication, and existing broader coordinated16168 rollout does not clear new extension provisioning or remote notification scope. No upload/distribution attempted. Production account/capability/versioned payload/NSE integration remains separate pending work, not silently wired to fixture IDs.

Safe integration is deliberately split: commit the full reviewed source as a REVIEW CANDIDATE branch, preserving source/evidence and recording signing/remote gates; integrate ONLY approved25 iOS icon PNGs and honest scope documentation to main. Do not merge production embed/communication entitlement/debug adapter as a completed feature while signing and production lifecycle remain unverified. This is partial main integration, NOT notification-feature completion/deployment. Original candidate checkout remains retained.

Fresh16186 gate: full1081 Flutter checks pass with17 environment skips; full analysis clean.149 Swift assertions and native3/3 approved final40–45 from immediately preceding exact code revision remain retained. Git fetched origin/main6eacf7a equals branch base; no text conflict. Source semantic/signing blockers above prevent claiming or merging this branch as a live production communication feature. Safe icon-only integration is separately identified.
