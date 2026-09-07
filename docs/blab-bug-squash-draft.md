# Blab bug-squash process — draft

Status: adopted as the reusable `blab-bug-squash` skill on 2026-08-31.

## 1. Understand the report

- Restate the expected behavior and the suspected failure in product language.
- Ask for confirmation before beginning the guided process.
- Keep the current app and user data intact unless the owner explicitly approves a reset.

## 2. Reproduce in the real flow

- Run the app locally in the Codex browser.
- Use realistic local accounts and the actual user flow, not a shortcut or isolated screen.
- Establish a visible baseline before changing the setting that triggers the bug.
- Capture the visible state at each important boundary.
- Wait for loading/translation states to settle before judging the result.

## 3. Test both participants

- Create or reuse a real Alice/Bob chat.
- Test the reported behavior from Alice's view.
- Mirror the same sequence from Bob's view.
- Keep each account in a separate browser origin so their sessions remain isolated.

## 4. Compare before and after

- Record the old state, trigger, transition state, and final state.
- Confirm the expected marker, copy, or state change appears.
- Check old content, new content, loading, failure, retry, and persistence separately.
- Use clear messages whose translations are easy to distinguish.
- Treat a transient loading state as evidence only after observing its final result.

## 5. Report the result

- Say exactly what passed and what failed in UX language.
- Separate the primary bug from incidental issues.
- Do not claim success from automated checks alone; the visible end-to-end behavior is authoritative.

## 6. Investigate before fixing

- Read the product requirement, technical decision, and current progress entry first.
- Trace the failing value from the visible message back through presentation, local state/cache, service calls, and stored data.
- Compare the working path with the failing path.
- Gather evidence for one root cause before proposing a change.
- Do not implement a fix until the owner asks for it.

## 7. Verify a future fix

- Repeat the exact reproduction that failed.
- Recheck both Alice and Bob.
- Reopen the chat and, where relevant, restart the app to verify persistence.
- Check adjacent states that share the same data path.
- Update project progress only after the owner confirms the matching manual test passed.

## Captured example: learning-language history

1. Send several messages while the viewer learns language A.
2. Confirm all completed messages display in language A.
3. Change the viewer to language B.
4. Confirm `Now learning [language B]` appears at the boundary.
5. Confirm completed messages above the boundary remain in language A.
6. Send another message after the switch.
7. Confirm only that new message displays in language B.
8. Mirror the sequence for the other participant.
