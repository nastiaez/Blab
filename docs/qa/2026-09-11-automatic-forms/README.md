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
- No production deployment, commit or GitHub push performed for this redesign.

## Owner review journey
Open the chat note → Change → Your gender form → choose the other form → Back. Confirm the note and its sentence update together, other completed messages do not change, and later messages do not repeat the note. Owner tracker remains unchecked until explicit confirmation.
