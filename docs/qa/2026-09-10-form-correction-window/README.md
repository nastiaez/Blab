# Immediate form correction — 10–11 September 2026

## Result

Owner-approved bounded correction behavior implemented and locally verified. Android debug APK and web package both built successfully. 33 focused UI/ledger/motion tests and 52 send/pagination/translation regressions pass; scoped static analysis clean. No owner launch checkbox completed. No commit/push of this work yet.

## Manual journey

Alice Local used the browser at localhost:7358; Bob Link QA used emulator-5554, chat `35c8e7cc-12c6-402d-a8df-6283e2e67674`. Real local messages/preferences; no fabricated translations or external recipients.

1. Clear Bob’s private partner fallback to Not set. Previously completed supermarket message remains frozen at its recorded masculine form.
2. Alice sends `I was tired yesterday.` (60001b89-aed3-48d1-a913-70fcfab62ee8): upstream false-success failure repeats; English remains. This defect is not fixed here.
3. Alice sends `Did you go to the supermarket yesterday?` (5adfe4d1-7645-4d44-9718-1bb1d74ba3c0): real Ukrainian alternatives arrive. Upstream subject metadata still incorrectly points at Alice, not Bob. This isolates correction mechanics, not correct person attribution.
4. Choose feminine: Ukrainian sentence resolves, confirmation/Change shown. Change opens choices; feminine can be selected again.
5. Chat Settings → partner form Masculine → Back: selected message becomes `Ти ходив до супермаркету вчора?`, confirmation masculine. Earlier completed message unchanged.
6. Process stop/restart and overnight interruption preserve the window. On the final installed version, Change stays open through repeated accessibility/UI hierarchy changes.
7. Alice browser sends `Thanks!`: incoming message closes the window immediately; confirmation/Change disappear. Translation eventually becomes `Дякую!`.
8. Chat Settings → partner form Feminine → Back: completed supermarket message stays masculine. Other completed history unchanged.

End state: Bob own form Not set; private partner fallback Feminine; active window closed. Alice browser remains in this chat. Added local QA messages retained.

## Screenshot index

- 01-choose.png: initial unresolved question (wrong-person label remains an upstream defect).
- 02-feminine-change.png: first chosen feminine + Change.
- 03-settings-masculine.png: initial Settings round-trip proof.
- 04-change-reopened.png: final version reopens choices and retains them after accessibility changes.
- 05-feminine-after-change.png: selecting again resolves feminine.
- 06-settings-corrected.png: final version Settings changes the eligible sentence to masculine.
- 07-later-preference-feminine.png: preference changed again after the next message.
- 08-history-unchanged.png: completed sentence remains masculine; next incoming message visible; no Change.
- 09-alice-browser.png: real browser sender-side messages.
- 10-final-reopen.png: final repackaged Android cold reopen; completed masculine message remains unchanged with the later Feminine preference and no active Change.

## Root cause found during device pass

The apparent inert Change tap was a state reset, not a missing tap handler: `MessageArrival` conditionally removed its animation wrappers when accessibleNavigation/reduced-motion changed. Descendant chooser state was recreated and `_editing` reset. Reproduced with a failing regression test, then fixed by retaining the same tree with identity transforms for reduced motion. Repeated native hierarchy inspection and selection now pass. The earlier duplicated chooser selection/confirmation condition and prepared-history metadata loss were also repaired.

## Remaining issues / coverage limits

- Wrong subject attribution and source-language false-success/absent Retry are still open; the full grammatical-form flow is NOT passed.
- General language matrix, multi-person linked choices and remote-device preference synchronization are not certified by this pass.
- Window/snapshot storage is account-scoped on this device; the immediate correction interaction does not transfer across devices.
- The broader message_learning_content suite has an unrelated pre-existing assertion expecting merged adjacent correction spans. Its failing test calls the unchanged `correctionSegments` function directly; this work does not modify that function. Other tests in that exploratory run passed after repairing Settings material containment. Final targeted suites above are green.

## UI review

Correction-window mechanics only: IA 8, interaction 8, clarity 8, visual continuity 8, intent fit 9, operational usefulness 8. Existing compact choices and 44px Change targets retained; Settings round trip and expiration are predictable. Full grammatical flow remains blocked by wrong-person attribution and false-success translation handling; those require their own repair cycle, not a completion claim here.

## Owner test

On a message with a genuine unresolved form, choose one → change matching Settings before either person sends anything → return and see it update. Send/receive the next message → change Settings again → confirm the completed sentence stays unchanged. Confirm this journey before checking the owner tracker.

## Final review repairs

Independent read-only review found two additional regressions, now fixed and covered by full ChatScreen tests: a cleared-and-closed unanswered snapshot must follow a later saved preference without reopening a window, and untouched multi-person messages must retain all unresolved markers. Local ledger failure after a successful remote edit/delete also no longer reports the server mutation as failed. Final combined run: 85 tests pass.
