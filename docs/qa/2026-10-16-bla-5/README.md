# BLA-5 — Contextual word meanings

Owner approved the exact wording in Telegram13635 on16 October2026.
Dedicated worktree `fix/sol-bla-5`, base4244141.

## Diagnosis and preference ownership

Read-only staging cache confirms message b95111c0-774d-499d-9045-415f7278dc10,
English learning output / Ukrainian Primary Known Language, had the same noun
meaning for `of`, `the` and `message.`. The client displays that saved mapping.
Practice sentence/audio remain owned by each viewer's historical Learning
Language; word definitions and secondary sentences use Primary Known Language.
Interface Language owns chrome only. No preference resolution changes.
Normal known/unknown-language behavior, learning aids off, tone, form and reading
script stay unchanged. Completed sentences remain authoritative.

## Change and cache boundary

Exact approved rule replaces the compact prompt's generic word-help line.
Metadata-only repair imports the same canonical wording. Generated rulebook
reflects it. Optional word metadata carries `contextual-word-meanings-v1`;
the existing sentence/storage contract remains unchanged. This intentionally
does not invalidate completed sentence history or trigger mass retranslations.
New message requests use the new stable prompt prefix (no compatible old prompt
prefix). Targeted metadata repair must compare the original row before replacing
only tokens, leaving all sentence/preferences/history fields untouched.

## Evidence boundaries

199 backend checks passed before metadata version annotation; final count follows
in verification receipt. Live probes use the repository default deployed-model
selection (no hosted OPENROUTER_MODEL override was present). A preliminary probe
with the local development model override (`openai/gpt-4o-mini`) still produced
incorrect meanings; that model is not accepted as proof of the candidate.
Default `google/gemini-3.1-flash-lite` produced article/preposition/noun meanings
for the reported sentence and separate financial/river-bank senses. One Ukrainian
repeated-context token list omitted articles: this is not full metadata coverage
and must not be presented as a complete pass for that fixture.

Native review replays the retained actual provider result through the real chat
screen, with outgoing English/known Ukrainian/interface English, then incoming
English/known German/interface Ukrainian. This proves client mapping and popup
presentation, not a live signed-in two-client hosted chat.

## Test delivery verified

Staging `translate-message`10 and `prepare-message-jobs`6 are ACTIVE.
All14 downloaded deployed TypeScript sources match this candidate byte-for-byte.
The reported en/uk message's shared cache and prepared package were repaired
using inspected live-provider tokens. Rollback rehearsal passed first; final
compare-and-swap transaction proves every non-token field unchanged, including
completion timestamp. It refuses active preparation or unexpected variants.
New metadata is versioned; completed sentences were not invalidated.

Android emulator5566 and iOS QA simulator both pass the real chat-popup replay
for `the`, `of`, `message` and the asymmetric German-meaning viewer. All8 actual
screenshots inspected; six attached to Linear, Android packet delivered13642,
iPhone sample13643. Motion unchanged, so no recording required.
199 backend checks pass, full Flutter suite959 before the new contextual test;
final full-suite result is recorded in the execution checkpoint. Analysis clean.
No hosted synthetic fixture, changed provider secret, schema migration, unchanged
client release, or production write. Production has no matching incident cache
variant, so its proposed scope is the same two backend functions only.

Production awaits the repository's16 October explicit rollout gate. The ticket's
auto-release label conflicts with that newer explicit project instruction; do
not silently treat implementation approval13635 as a new production rollout.
Physical-device/live signed-in two-client end-to-end verification is not claimed.

