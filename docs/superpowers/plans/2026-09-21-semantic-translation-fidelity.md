# Semantic Translation Fidelity Implementation Plan

**Goal:** Prevent cross-language false-friend drift without a dictionary or a
sentence-specific replacement.

### Task 1: Lock the contract

- Add failing tests requiring false-friend and back-translation guidance in
  the standard and focused translation prompts.
- Run the focused tests and confirm they fail for the missing rule.

### Task 2: Add the smallest general safeguard

- Add identical meaning-first, false-friend, and back-translation guidance to
  both translation paths.
- Rerun the exact fixture. If prompt-only guidance still fails, reject it as
  insufficient.
- Add a narrow audit that independently renders source and candidate meanings,
  preserves equivalent results, and returns one corrected target sentence only
  for an explicit mismatch.
- Regenerate word metadata only for a corrected sentence.
- Run the focused and full language-engine suites.

### Task 3: Prove the real Ukrainian case

- Refresh the cache contract and regenerate the exact L11 two-user fixture.
- Verify `librairie` becomes Ukrainian `книгарню`, and confirm matching word
  help, romanization, and Ukrainian audio in both real clients.
- Run the complete release gate and send repaired screenshots for approval.
