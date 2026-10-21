# BLA-15 update routing · request14553

Candidate branch fix/bla15-update-destinations-20261020, based on main6a9454f. No commit, merge, release or notice activation in this task. Banner design unchanged.

## Fix

Exact private destinations are accepted only for their own channel/platform. Public Google Play/App Store destinations remain supported. Cross-app/private routes, modified paths, queries, userinfo and insecure schemes are rejected by regression checks.

## Verification

- Five focused tests pass; full suite982 pass/16 environment skips. Static analysis clean and diff whitespace check clean.
- Actual Android production widget and url_launcher externalApplication callback used in a QA-only fixture. Installed29/latest30 and channel are controlled data; chat/auth/network providers are preview data. The launcher is not replaced.
- Android public/test button taps dispatch the exact respective Firebase URI to Chrome. Activity receipts are local raw diagnostics, not authenticated download/install proof.
- Managed mobile browser independently identifies the target apps as Blab and Blab-test. New-device consent was not accepted.
- App Store Connect read-only app identity checks match public6823314008 and test6823316052 to their respective bundle IDs. Apple HTTPS invitation pages expose corresponding itms-beta native links.
- iOS simulator openurl exercises OS/Safari dispatch, NOT a newly built Flutter iOS button or TestFlight client installation. Second simulator screenshot is blank/loading and rejected as successful-page evidence. No fresh authenticated install or physical-device proof claimed.

## Activation boundary

Build30 is unchanged and its compiled public validator does not accept these private destinations. A new reviewed integrated build is required. Existing notice metadata is unchanged/disabled; no unavailable future build is advertised. After release availability and native acceptance, configure each matching destination/latest build, then enable and verify older-versus-current version gating. This candidate is not a live notice.

## Evidence

Android01/03 show the same compact banner with explicitly labeled fixture footer. Android activity receipts record exact public/test URI handoff. apple-destination-identity.json records app identity checks. manifest.json records source/artifact hashes and test results. Test logs retained at /tmp/blab-bla15-routing-{green,full,final-analyze}.log.
