# Invite picker V16 · implementation review candidate · 22 October 2026

## Scope and authority
Nastia approved Paper V16's contained search field and said “looks good, build it”.
Canonical Paper: https://app.paper.design/file/01M54K6J9EQ56GP909AWJHEKPQ/p-C-0
Latest approved design is the 15491 WhatsApp-container correction, not the earlier
plain header text. Existing dedicated feat/group-inapp-invites-20261021 refreshed
onto current main617639c; prior dirty invitation candidate/autostash preserved.
Source manifest identifies this uncommitted candidate. No main/source publication,
hosted migrations/functions, tester distribution or update-notice change.

## Implemented journey
Group Invite friends restores the people picker. Normal header has a 48px Search
target; search replaces the title with a 366x56 rounded neutral container, Back
inside, localized Search friends placeholder, and Clear when nonempty. External
Invite outside Blab / Share a link stays above the friends. Existing Blab selection
rows/checkmarks, 64px contact rows, 8px gaps, cream/orange palette, disabled palette
and pinned 52px action retained. Filtering hides results but does not discard
selected IDs; Clear removes query, Back closes search before leaving picker.
Copy/Share returns to the same selection. Names only, no promised phone/username
lookup. Personal link and existing reset-confirmation work preserved.

## Verification
- Final full Flutter gate: 1056 pass, 17 environment-gated skips.
- Final analysis clean; diff whitespace check clean. Web and Android builds pass.
- Focused initial packet45 pass; scroll/search packet12 pass. Tests include failed
  load/retry, failed send/retained selection, localized 320px layouts at100/200%
  in en/de/es/uk, contained field, Clear, Back and hidden selection count.
- Installed Android5560 integration passes: real isolated local Supabase59521,
  Alice selects Bob/Carol, filters and clears, system keyboard/search Back,
  Copy/native Share and return, sends only Bob; Bob inbox contains invitation,
  Carol inbox does not; group membership remains1. No hosted/real-user sends.
- Final source also exercised outside the test harness via real Android input:
  native keyboard, empty/selected/filtered field, Clear/Back, Copy/Share and return.
  Nine actual full-frame780x1734 captures in live-android/ inspected against
  Paper; real-touch recording sampled/inspected. No reconstructed screenshots.
  live-android/ is the canonical delivered visual packet; android/ retains earlier
  automated captures as diagnostic evidence, not a substitute for the live replay.
- Flutter Web390x867 root0,0, no document overflow; final contained-search capture
  inspected. Earlier Web filtering/clear/back preserves2 selections. Native Android
  is target-platform visual evidence; desktop Flutter typography is not pixel parity.
- Interrupted final runs failed due disk-full; recovered with26GiB available,
  restored unresponsive local Docker, reran final gates successfully. No data reset.

## Delivery and remaining gate
Screens15539–15542 and actual walkthrough15543 delivered to original topic7420.
Receipts confirmed. These actual implementation screenshots await visual acceptance;
Paper approval does not approve unseen implementation or authorize integration.
No commit/push/main integration/release yet. Physical-phone/iOS/hosted private-invite
acceptance not claimed. Existing local candidate migration remains undeployed.


## Integration authorization · 22 October 2026 ·15553
Nastia reviewed the actual Android packet15539–15543 and explicitly requested
“check for conflicts, commit and merge to main”. This supersedes the pending
visual/integration authorization above for this invitation slice only. No hosted
migration, service deployment, update notice or tester distribution is authorized.
Fetched origin/main617639c equals the reviewed candidate base: no textual merge
conflict or intervening main changes. All reviewed source hashes match the final
V16 manifest. Historical exploratory tests/captures remain in the retained checkout;
only final V16 native acceptance and its QA entry are promoted. Manual physical
phone/iOS/hosted acceptance remains open; the launch tracker stays unchecked.
