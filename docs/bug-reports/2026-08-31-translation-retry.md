# Translation needs manual Retry — reproduction record

Status: clean browser path observed; owner confirmation still required.

## Expected

A new supported-language message resolves into the viewer's active learning language without manual action.

## Observed

In Bob's local browser chat with Alice, the first French-era messages showed `Couldn't translate · Retry` after their initial request. Tapping Retry resolved them into French. A later French message and two Dutch-era messages resolved on the first attempt.

## Reproduction

1. Start from the existing Alice/Bob chat in Practice mode.
2. Change Bob's learning language from Spanish to French.
3. Send a short English message.
4. Wait for completion.

The failure is intermittent: it occurred for the first two French messages and was recoverable through the visible Retry action. It did not change the preserved Spanish/French/Dutch history boundaries.

## Initial evidence

- The local `translate-message` worker reported runtime CPU-limit/worker-retirement failures during the failed requests, including requests cancelled by its supervisor.
- The chat changes a still-loading bubble to the Retry state after 10 seconds. It uses the same 10-second total budget for its quiet retry, so a first request that reaches that boundary cannot receive a meaningful second attempt.
- Bob's prepared translations took 24.5 seconds, 64.2 seconds, and 18.1 seconds for the three French messages, and 11.8 seconds for the first Dutch message. All are longer than the 10-second chat deadline; only the second Dutch message completed in time (8.5 seconds).
- The background preparation path fans a new message out into viewer-specific translation jobs while the visible chat can also request the same translation. During the failed French attempts, the local Edge runtime retired workers before completion; later attempts succeeded through the same provider.
- This is tracked separately from the repaired learning-language history regression.

## Root cause

This is a reliability and timing bug, not a language-era bug. The visible chat declares a translation failed after 10 seconds even though a valid translation commonly takes longer. At the same time, the local preparation worker can be overwhelmed by concurrent viewer jobs and live requests, causing its runtime to cancel or retire workers. Retry succeeds because the service has recovered or the delayed background job has finished and cached the result.

## Repair

Page hydration now only reads prepared results and rechecks them shortly afterwards. It no longer starts separate provider requests for every message on the page, so the delivery worker remains the single background owner. A message that is actually on screen keeps the existing recovery path. If a valid result reaches the cache just after the ten-second visual boundary, the bubble checks once more and replaces Retry automatically.

Focused translation-state and related chat-history checks pass. The real-browser confirmation remains open because the in-app send control did not accept the automated tap during this run.

## Browser-test environment note — 2026-09-01

After the local app was restarted, its translation service was not yet running. A new Bob message correctly showed Retry in that unavailable state; once the service was restored, Retry produced the Italian result (`Le candele sono accese.`). This does not exercise or invalidate the timing repair. The remaining browser check is a fresh message sent while the translation service is already running.

## Clean browser result — 2026-09-01

With the translation service running before send, Bob sent `The window is open.` while learning Italian. After the message settled, it rendered as `La finestra è aperta.` with no Retry action. The owner still needs to confirm this manual browser pass before the tracker can close it.

The clean path was repeated immediately afterwards with `The room is quiet.`. It settled as `La stanza è silenziosa.` with no Retry action.
