# Message lifecycle parity verification

Date: 2026-09-11

Device: Android 16 emulator, 1080 × 2400

Scope: incoming/outgoing translation motion, single and simultaneous incoming messages, reduced motion

## Result

The incoming placeholder now uses the same message-owned state machine as the outgoing bubble. Its two neutral lines are the only elements that receive the traveling light band. Resolution clears the pending content, reshapes the empty bubble, and lands the translated text. Incoming authored text is never visible before success.

## Device matrix

| Scenario | Result | Evidence |
| --- | --- | --- |
| Slow outgoing + incoming | Pass | `message-lifecycle-normal.mp4`, `01-wave.png`, `02-landed.png` |
| Single incoming pending | Pass; no separate status row | `01-wave.png` |
| Two simultaneous incoming messages | Pass; independent waves and one `Translating 2 messages…` count | `03-simultaneous.png`, `message-lifecycle-normal.mp4` |
| Oldest-first independent completion | Pass; first bubble lands while the second keeps its own phase | `message-lifecycle-normal.mp4` |
| Reduced motion | Pass; static placeholders swap directly to final text with no wave, clear, resize, or landing animation | `message-lifecycle-reduced.mp4` |
| Settled final state | Pass; no duplicate/source text and no leftover status | `04-final.png` |

The video uses the real production `TranslatingMessageContent` widget in the Android device preview so timing is deterministic. The local provider was returning unrelated 502 audit failures during live-data setup; chat-screen integration tests therefore supply controlled translation completion while exercising the production chat composition and ordering logic.

## Automated evidence

- Focused lifecycle and chat-screen tests cover slow resolution, one pending incoming message, reduced motion, and two simultaneous incoming messages.
- Existing coverage retains fast/medium branches, failure/retry, cached results, and off-screen completion behavior.
- Full verification: Dart formatting clean, Flutter analyzer clean, 466 tests passed with 15 intentional skips, and `git diff --check` clean.

## UI review

- Information architecture: 9/10
- Interaction design: 9/10
- Trust and clarity: 9/10
- Visual polish: 9/10
- Fit to approved intent: 10/10
- Operational usefulness: 9/10

No further cycle was required. The pending treatment is visually subordinate to real messages, both directions share the same timing vocabulary, the simultaneous count appears only when it adds information, and reduced motion removes every nonessential transition.
