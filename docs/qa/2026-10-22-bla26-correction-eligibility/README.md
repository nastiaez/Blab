# BLA-26 correction eligibility

Current-main base d983a6a; dedicated fix/bla26-correction-eligibility-20261022. Candidate only, no commit/integration/release.

## Preference/output mapping
- Each viewer’s applicable Learning Language owns Practice primary output. Source language must match it before correction marks are eligible.
- Authorship plus immutable languagesMatchedAtSend still gates sharing; current partner settings never rewrite historical eligibility.
- Primary Known Language owns expanded secondary text/word help, independent of Interface Language.
- Interface Language controls chrome only. Normal known-source exact text, unknown-source translated text, aids-off and historical results stay unchanged.

## Root-cause boundary
The active nonempty response path preserves optional mode metadata. Presentation trusted correction mode without checking the actual source language. Existing rulebook already forbids cross-language corrections; this guard enforces it at display time for both fresh and cached results. No prompt/policy/cache contract changes, sentence rejection, deletion, or historical regeneration. A provider misidentifying the actual source itself is outside this deterministic guard and remains a live-reproduction boundary.

## Evidence
Red-before reproduction for stale correction metadata; green-after 39 message-learning checks. EN→DE and ES→FR each exercised as author and historically matched recipient. Genuine same-language correction remains covered by existing checks. Native real ChatScreen fixture uses injected cached EN→DE correction metadata and Ukrainian chrome, English meanings; no live AI or user account. Actual native capture pending.

Task-owned serial compiler cache is shared with BLA25 through a build symlink only; runtime source remains this worktree. No concurrent builds use it. All evidence must be attributed to this candidate, not BLA25 output.

Final verification: 1,040 full client checks pass /16 environment skips, analysis clean; actual Android5580 sender+receiver cached-metadata fixture passes. Both captures inspected; receiver delivered15361 and both attached to Linear. No live AI/hosted/iOS/phone acceptance; status Testing. Screenshot review pending, no commit/merge/release.
