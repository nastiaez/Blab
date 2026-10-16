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
199 backend checks and961 Flutter checks pass (15 existing skips); analysis,
format and whitespace checks pass.

## Production release verified

Owner13647 explicitly approved the same production scope. Integrated unchanged
candidate11606ea into synchronized local/remote main. All three clean CI gates
passed: https://github.com/nastiaez/Blab/actions/runs/38915719622 .
Production translate-message33 / prepare-message-jobs12 ACTIVE, JWT checks retained.
All14 downloaded deployed TypeScript files match the approved source byte-for-byte.
Preflight matched the previous production source and all103 migrations; no schema,
secrets, access settings, client artifact or production chat data changed.
No matching incident cache variant exists in production, so no historical repair
was performed there. The two production endpoints still reject unauthenticated
requests with401. Fresh generation through the downloaded production source and
the same default model returns article/preposition/noun meanings correctly for
the incident sentence, with separate Ukrainian/German viewer meanings.

Evidence boundary: this is deployed-source verification plus a fresh provider
probe and native rendering evidence, not an authenticated production-client or
physical-device end-to-end run. No such acceptance is claimed. Full receipts:
/Users/aswin/clawd/projects/blab/qa-artifacts/BLA-5/receipt.json .
