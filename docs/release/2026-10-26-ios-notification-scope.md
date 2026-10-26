# iOS notification review16186 — partial integration, not live deployment

Owner approved native local screenshots40–45 and requested commit/main integration.
Only25 approved iOS AppIcon PNG assets are safe for main now: exact supplied SVG
orange#F88C5A/ink#181616 arrow, no Android/unrelated launcher branch changes.

Full communication notification source is a separate reviewed candidate, NOT a
completed remote notification implementation. DEBUG review sender/count fixtures
must not become production identities. Versioned iOS capability/payload/NSE,
receiver/account-epoch lifecycle, remote delivery and authenticated warm/cold taps
remain unimplemented/unaccepted. Existing production delivery is unchanged.

Executed candidate iphoneos Release extension build fails: no provisioning profile
for blab.nastia.ez.test.NotificationContent. Existing parent profile is insufficient.
No physical iPhone connected. Creating extension identifiers/profiles or changing
hosted iOS payload/capability scope has not been authorized/executed by this slice.

Existing private iOS channel: TestFlight, regular6823314008/test6823316052; no new
TestFlight/App Store upload or distribution authorized or performed for this slice.
Main icon integration is NOT communication notification deployment or live success.

Visual evidence/source provenance remains in retained candidate QA directory
2026-10-26-ios-notifications; final40–45 approved, prior cache30–35 rejected.
Native compact badge uses OS rounded-square app-icon mask; expanded circular custom
badge/initials/privacy remains approved but pending production integration/signing.
