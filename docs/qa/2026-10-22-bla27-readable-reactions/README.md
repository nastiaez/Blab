# BLA-27 readable long-message selection

Base d983a6a; dedicated fix/bla27-readable-reactions-20261022. Uncommitted, unmerged, unreleased.

## Behavior
Long bilingual Practice selections (and long Normal Original selections) reserve a centered emoji strip below the header, outside the scrollable text. Long means bubble height exceeds half the available reading area. The selected expanded text remains open during finger scroll. Short-message floating placement, dismiss-on-tap/back, all existing message actions and More remain unchanged. No message-language, cache, backend or provider change.

## Preference mapping
Each viewer’s chat Learning Language still owns Practice primary output; Primary Known Language still owns secondary/word help. Interface Language owns chrome only. Existing Normal/aids-off/history behavior unchanged.

## Verification
- Red-before/green-after actual ChatScreen long-message regression.
- Full client1,040 pass /16 environment skips; final analysis clean, diff whitespace clean.
- Actual Android5580 incoming/outgoing cached-message fixtures pass at411x914 and320x640 logical sizes. Original remains present through finger scroll; reaction strip is geometrically outside ChatTimeline; Reply and More/emoji picker accessible.
- Eight native PNGs inspected. Native recordings inspected; review clip is a trim of the actual raw screen recording (raw retained). Fixture text/translation is injected cached test data, not live AI or two-account backend proof.
- Screenshot15366 and recording15368 delivered to topic7501. Two PNGs and recording attached to Linear. Status Testing, not delivered to a hosted test app.

## Review/release boundary
Actual screenshot/workflow review pending. No commit, main integration, hosted action, Firebase delivery or notice update. Follow the standing exact-scope approval contract before phone distribution; no unseen implementation approval inferred.

Serial task-owned compiler cache shared through build symlink with BLA25 only. Runtime source is this worktree. No simultaneous native builds. Synthetic emulator public package was replaced for tests; no physical phone/user-data-retention claim.
