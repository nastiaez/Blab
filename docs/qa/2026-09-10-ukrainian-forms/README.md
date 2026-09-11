# Ukrainian grammatical-form manual test — 2026-09-10

Scope: owner authorized the first Ukrainian test using Alice browser and Bob emulator. No app/source fixes were authorized or made.

Environment: local backend; existing debug Android on emulator-5554; Alice Local browser at localhost:7358; Bob Link QA Android; chat 35c8e7cc-12c6-402d-a8df-6283e2e67674. Bob changed learning language from German to Ukrainian through the UI. Historical German messages remain in their language era. Both account forms and both relationship fallbacks initially null.

## Results

1. **Required choice appears — partial pass, wrong subject FAIL.** Alice authored `Did you go to the supermarket yesterday?`. Bob received `Ти … до супермаркету вчора?` with `ходила` and `ходив`. The chooser incorrectly said `Choose Alice Local's gendered form`; it must identify Bob/the viewer for incoming `you`. Cached payload had subjectName Alice Local and subjectIsViewer false. Screenshot 01.
2. **Feminine resolution — rendering pass, ownership FAIL.** Tapped ходила / feminine. Sentence rendered `Ти ходила до супермаркету вчора?`, confirmation said Alice Local: feminine. Database showed Bob's partner fallback feminine and Bob's own form still null; Alice's actual account remained unchanged. Screenshots 02–03.
3. **Temporary Change — FAIL.** Tapped Change twice, with fresh UI dumps between attempts. Neither reopened the chooser; feminine confirmation remained. Do not claim masculine inline choice passed.
4. **Settings persistence — PASS for stored relationship fallback only.** Opened Chat → Translation preferences and changed Alice Local's form to Masculine. Force-stopped/relaunched Blab, reopened chat/settings. Masculine remained visible and persisted in Bob's private partner fallback; both account-wide forms still null. Screenshot 04. This does not establish correct subject ownership, self-form persistence, or future translation correctness.
5. **Outgoing self-reference — FAIL before choice.** Bob authored `I was tired yesterday.` while learning Ukrainian. The message remained English. Stored target_lang uk row had source_lang uk and aid_mode none, with unchanged English translation_text and no alternatives. Screenshot 05. Root cause not established; self-reference chooser and masculine selection could not be completed in this run.

## End state / follow-up

Bob remains signed in, learning Ukrainian. Bob's private fallback for Alice is Masculine (set by this test); both own forms remain Not set. Two test messages retained. No production settings or data changed. Tests must reset local preferences deliberately before the next unknown-state run.

Do not mark the full grammar matrix complete. Correct-subject mapping, Change interaction and outgoing language handling require investigation and repair approval. Remaining languages, masculine inline selection, self-memory, later-message reuse, contradiction, multiple-person cases, caption, localization and failure/retry matrix remain unverified by this run.
