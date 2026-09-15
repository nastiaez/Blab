# Hindi and Tamil reading-script QA

Date: 2026-09-14

Environment: local Supabase, Alice in the Flutter web client, Bob in the Android emulator. No staging or production data was changed.

## Local fixture

- Alice and Bob shared chat: `59a77132-b089-4b8e-942e-7093610797d7`.
- Alice learned Tamil and Bob learned Hindi in the same conversation.
- The one account-wide Reading script preference was exercised from both clients.

## Device matrix

| Case | Result | Evidence |
| --- | --- | --- |
| Native script is the default for Hindi and Tamil | Pass | Bob initially rendered the Hindi learning sentence in Devanagari; Alice initially rendered Tamil script before either account changed the preference |
| Eligible chat preferences show one contextual Reading script row | Pass | `screenshots/01-alice-reading-script-row.png`, `screenshots/04-bob-reading-script-row.png` |
| The choice sheet matches the current checkmarked settings pattern | Pass | `screenshots/02-alice-reading-script-sheet.png`, `screenshots/05-bob-reading-script-sheet.png` |
| Tamil generated learning text switches to complete English-letter text | Pass | `screenshots/03-alice-tamil-english-letters.png` |
| Hindi current and past generated learning text switches immediately to complete English-letter text | Pass | `screenshots/06-bob-hindi-english-letters.png` |
| Switching the chat from Hindi to French hides Reading script | Pass | Bob's Android Translation preferences showed only gender form and tone while the chat used French |
| Switching the chat back to Hindi restores the saved English-letter choice | Pass | Bob's Android Translation preferences restored `Leseschrift · Lateinische Buchstaben` |
| English-letter word descriptions make Romanization primary and native script secondary | Pass | `screenshots/07-bob-word-popup-english.png` |
| Word meaning and native-language audio remain available | Pass | `screenshots/07-bob-word-popup-english.png` plus focused interaction coverage |
| Alice-to-Bob and Bob-to-Alice messages remain visible in the shared chat | Pass | Alice browser and Bob Android conversation passes |
| Profile exposes the same contextual preference after refreshing a stale chat list | Pass | `screenshots/08-profile-entry.png`, `screenshots/09-profile-reading-script-row.png`, `screenshots/10-profile-reading-script-sheet.png` |

## Contract coverage

| Case | Result | Evidence |
| --- | --- | --- |
| Switching Reading script re-renders cached eligible history without a new translation request | Pass | Device switch was immediate; focused regression asserts zero new live preparation calls |
| Incomplete Romanization falls back to the complete native sentence | Pass | Focused sentence-rendering regressions for Hindi and Tamil |
| Authored native-script and Romanized input remains exact | Pass | Focused message-rendering regressions |
| Reading script never becomes a correction rule | Pass | Focused learning-message regressions |
| Generated corrections and matching reply previews follow Reading script | Pass | Focused chat rendering and quoted-reply regressions |
| Profile and chat entry points share the same account preference | Pass | Preference persistence and settings synchronization regressions |

## Visual review

- The row, current-value hierarchy, dividers, checkmark, and bottom-sheet behavior reuse the refreshed Translation preferences pattern.
- Hindi and Tamil sentences wrap without clipping in the Android chat; the browser remains a wide test client rather than the Android launch target.
- The longest tested German settings labels remain readable without overlapping the trailing value.
- No blocking hierarchy, spacing, contrast, or interaction issue was found in this pass.

UI/UX review scores: information architecture 9/10, interaction design 9/10, trust and clarity 9/10, visual polish 9/10, fit to user intent 10/10, and operational usefulness 9/10. Every category passes the 8/10 review gate; no additional UI cycle is required before owner review.

## Notes and limitations

- Reading script appears only when the active learning language is Hindi or Tamil. The saved account preference remains while the row is hidden.
- The same native/English-letter choice applies to both Hindi and Tamil.
- Changing Reading script does not rerun translation, correction, or grammatical-form analysis.
- Exact authored text and Original remain unchanged; only Blab-generated learning text changes notation.
- Existing language-era boundaries remain unchanged when the learning language itself changes.
- The owner approved the Alice/Bob and Profile screenshots and requested integration to `main` on 2026-09-14.

## Automated verification

- `dart format --output=none --set-exit-if-changed lib test`: clean.
- `flutter analyze`: no issues.
- `flutter test`: 520 passed, 15 environment-gated skips.
- `supabase test db`: 146 passed.
- `scripts/local_test.sh integration`: Realtime readiness plus 11 integration checks passed; 3 live-provider checks skipped because their development key was not enabled.
- `git diff --check`: clean.
