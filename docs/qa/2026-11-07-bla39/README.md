# BLA-39 candidate18455 — implementation, NOT release acceptance

Request: Anastasiia Yezhyzhanska356111473, topic8856/message18455,7 November2026. Dedicated ../blab-bla39-profile-photos-18455, branch feat/bla39-profile-photos-18455, fetched-main base ebdcc1d9d19b48d4a7eb0b45bef8290da4fdb31f. No application commit, push, main integration, backend deployment, tester distribution, public publication or Linear comment performed.

## Approved scope
Frozen Paper file01M3PCM6SC0AMB5Q0M3AZ58WBR/page p-N-0;5EQ-0(entry),5CK-0(empty),5GG-0(crop),5DM-0(selected draft),5FK-0(removal draft). Real name only;112px avatar,44px dark/white20px pencil and removal;160px editor avatar; black crop, orange56px/dark20px tick. Native single-image Camera/Photo; crop confirms draft, Save commits, Back discards. No illustrations/custom gallery/text creation/extra signup screen. Google initialization only on new-account profile INSERT, never login/backfill/sync; signup remains name-only.

## Implementation
- Dedicated photo/name entry; existing name editor retained separately; shared Telegram motion.
- Native image_picker, cancellation/error recovery, EXIF normalization,20MiB/40MP decode limits, bounded pan/zoom, real512px JPEG crop; draft isolation.
- Stable avatar cache identity; private versioned objects,60-second signed links; shared person renderer across profile, chat/list/header, mentions, senders, members, invitations and reaction rows with known IDs. Group-only identities remain initials.
- RPC binds initiating account, validates ownership/existence/MIME and serializes pointer changes; direct client avatar-path writes revoked. Ambiguous commit never deletes a possibly committed current object.
- Durable orphan cleanup with15-minute grace, leases/current-reference exclusion/commit fencing, retries, account-erasure integration and physical removal verification. Successful cleanup deletes identity-bearing queue row. SQL + delete-account + reconcile-stream-events require coordinated reviewed deployment; nothing deployed.
- Four interface locales. Privacy source updated for photos/Google/visibility/external requests/removal limits; NOT published, NOT legal certification.

## Verification boundaries
Actual Android fixture uses production UI and real OS picker/crop, but INJECTED persistence callbacks, not live upload/peer visibility. Stock portrait is approved Paper fixture. Screenshots must be inspected; callbacks are not account/storage end-to-end proof.

iOS first isolated-bundle attempt correctly failed identity guard. Prescribed prepare_ios.py/staging configuration subsequently built successfully. Native rendering/picker status still to record. New fixture substitutes image selection on iOS only; NOT actual iOS system-picker evidence.

SQL execution BLOCKED: Docker ps/info timed out; no psql. ZERO SQL assertions executed. SQL-CHECK.md. No existing backend/service/schema reset/mutation/restart. Canonical rebuild, real RLS/cleanup/upload/relogin/peer visibility remain unverified.

GOOGLE-REVIEW.md: source/SDK/documentation only. Actual first/returning Android+iOS consent, console/client associations, deployed trigger/provider payload unverified. No Google Photos permission. Privacy source edits do not prove publication/compliance.

## Retained failures/corrections
- Initial Android packet rejected two-letter initials/swatch, oversized glyphs and inherited header ink; corrected to frozen single initial/swatch, constrained20px glyphs and black header. android-initial-rejected/ is superseded; do NOT deliver as accepted proof.
- Emulator host graphics lost device/SIGPIPE; leased device recovered with headless SwiftShader/Vulkan disabled. Other owners untouched.
- Initial suite found pending45-second timers in unauthenticated fixtures; renewal moved after valid authenticated client/identity. Focused80 header/bubble checks passed.
- Next full run had one old CircleAvatar-only reaction assertion; updated to shared renderer preserving colour/size.
- Disk exhaustion errno28 interrupted later checks; those are FAILURES, not passes. Owned idle iOS simulator shut down for pressure. No source/evidence/other worktree/global cache/user data deleted.
- Affected deletion tests referenced obsolete renamed migration; corrected to canonical20261103000000.

## Open acceptance
Record final gates and inspect corrected native packet. Verify both platform flows at390×844/100%, actual storage/authorization/deletion and Google lifecycle. Implementation screenshot/journey approval required before commit/push/merge/deployment/distribution. Static approval is not implementation approval.
