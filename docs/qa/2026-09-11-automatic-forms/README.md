# Automatic grammatical forms — local verification, 11 September 2026

## Scope and result
Approved chat-screen simplification implemented locally; Android and web packages produced. This is not certification of all grammar languages, production deployment, or owner acceptance. The old chooser/next-message cutoff is superseded.

Real Alice Local browser → Bob Link QA Android-emulator journey:
1. Alice sent “Did you visit the museum yesterday?”; Bob received a complete Ukrainian sentence with one `Using feminine forms for Bob Link QA` note, correctly identifying the recipient rather than Alice. Screenshot 01.
2. Change opened the existing Translation preferences page, with Your gender form / Alice Local's gender form / Conversation tone. Screenshot 02.
3. Bob selected Masculine under Your gender form. Screenshot 03.
4. Back in chat, only the annotated museum sentence changed to `Ти відвідав музей вчора?`; older completed supermarket sentences stayed unchanged. Subsequent messages have no repeated note. Screenshot 04.
5. Fresh “Were you tired yesterday?” produced real server alternatives with stable recipient role, Bob name and masculine suggestion. “Did you go to the park today?” produced masculine suggestion after the saved preference; the displayed sentence was masculine. No fabricated provider responses.
6. Reinstalled/reopened the final Android package: masculine note, matching museum sentence, and later messages persist. Screenshot 05. Alice browser shows the same sent messages as complete English sentences (her learning language is English), screenshot 06.

The first museum result predates the stronger direct-subject audit hint and guessed feminine. That provisional snapshot was intentionally retained for the correction test; a subsequent real request verified Bob → masculine after the hint repair. Ambiguous-name feminine fallback, saved-form priority, persistence/account isolation, no marker/chooser, migration, bounded history correction, incoming recipient binding, Change routing, and Copy matching masculine display have automated coverage.

## Checks
- 37 focused Flutter checks pass, including real ChatScreen Copy and Change navigation.
- 4 new server ownership checks pass; server type check passes; scoped Flutter analysis has no issues.
- Broader regression: 37 pass / 2 reply-preview failures. Both failures reproduce on isolated HEAD (reply-baseline.log), unrelated to this change.
- Server contract suite: 40 pass / 1 existing corrected-interface-text failure. Isolated HEAD had that same failure plus five obsolete gender-prompt assertions. The five assertions were updated for the owner-approved redesign, not hidden.
- Independent bounded review: saved-form metadata, action/quote consistency, migration and positive direct-sentence ownership checks reviewed; no remaining blocker in that reviewed scope.

## Open, not counted as done
- Chats-list preview still uses canonical feminine text in cases where the bubble displays masculine. Captured after restarting Bob: park preview feminine vs masculine bubble. Track as a separate visible-preview follow-up; no claim it is fixed.
- Existing false-success/source-language bug hides Retry for old “I was tired yesterday.” messages. They remain visible in historical screenshots; not repaired by this task.
- Full 11-language/caption/multi-person matrix, physical-device typography/accessibility pass, cross-device correction-note synchronization and owner confirmation remain unverified. Local note history is account/device scoped as documented.
- No production deployment was performed; branch publication is handled as a separate release step.

## Owner review journey
Open the chat note → Change → Your gender form → choose the other form → Back. Confirm the note and its sentence update together, other completed messages do not change, and later messages do not repeat the note. Owner tracker remains unchecked until explicit confirmation.

## Self-routing UX correction
- Viewer-owned notes now say `Using feminine forms for you` or `Using masculine forms for you`; partner-owned notes retain the partner's display name.
- `Change` carries the note subject into Translation preferences and opens the matching grammatical-form picker immediately. The verified viewer journey opens `Your gender form`, not the partner row.
- Fresh installed-Android evidence captures feminine viewer copy, the directly opened viewer picker, and the resulting masculine sentence/note. Focused Flutter verification passes 25 tests; scoped analysis, formatting, `git diff --check`, and the Impeccable detector are clean.

## Hardening follow-up
- Shared translation and prepared-package alternatives now use stable `author` / `recipient` ownership and cannot include either viewer's saved form. A migration invalidates every legacy shared/prepared cache variant, replaces completed/in-flight jobs with fresh IDs, and requires a v2 completion contract so stale workers or foreground requests cannot repopulate private preference-dependent output. Database checks enforce both cache version and the stable form shape.
- Feminine and masculine renderings now carry independently validated full-sentence token arrays, so either visible form keeps the correct gloss and romanization metadata.
- Provisional name-based suggestions stay local and do not write account or partner preferences. Saved preferences remain authoritative; clearing returns to the original suggestion.
- Edited and deleted messages release their note ownership. A delayed callback is rejected by the ledger unless the exact message ID and source snapshot still exist. Switching target language transfers the note to the same message instead of orphaning it.
- Focused Flutter verification: 29 ledger/note/chat tests pass; the masculine-token and Normal-known-source regressions pass independently. Scoped analysis, formatting, `deno check`, and `git diff --check` pass.
- Direct-person normalization no longer guesses from generic word endings. It accepts explicit or tightly bounded language forms, recognizes participant names directly, permits capitalized German nouns, distinguishes Dutch subject `je` from possessive `je`, and leaves ambiguous Italian `sono` clauses to the audit. Controls cover ordinary English/German sentences plus the reported Dutch, Italian, Portuguese, and Spanish false positives.
- Translate-message verification after deferred-failure cleanup: 74 tests pass with no failures.
- Full Flutter verification after deferred-failure cleanup: 462 pass, 15 skip, with no failures.
- Owner/device/language-matrix gates remain open. No production deployment was performed.

## Deferred failure cleanup
- The corrected-interface failure was a real server/database contradiction: the provider contract requested a clean interface-language sentence, but TypeScript normalization restored the authored mistake and both completion RPCs rejected any corrected value. Corrected interface text is now preserved while same target/interface lanes remain strictly identical.
- The two reply-preview failures shared a stale test fixture. Cached Tamil quote rendering already worked, but the fake omitted the required viewer-private language timeline, so the parent bubble remained behind the historical-language safety gate. Both reply fixtures now provide a baseline language era and prove that cached parent/quote text renders without a live provider call.
- The seven bubble-action failures had the same missing-timeline fixture root cause. Restoring the baseline era makes the existing failure hints, long-press actions, TTS, Original toggle, Reply action, and mode-switch dismissal assertions pass without production UI changes.
- The remaining correction assertion expected one fused span. The renderer intentionally separates replacement words and punctuation into independently tappable segments; the test now verifies unchanged, struck, and corrected semantics directly.
- GitHub coverage exposed a final timeout-ordering race: when the live request deadline fired before the visual loading timeout, its catch path cancelled the only timer that would recover a cache row committed just after the deadline. Timeout failures now schedule the same bounded late-cache recheck directly. A deterministic regression keeps the visual timer later than the request deadline and passes under coverage.
