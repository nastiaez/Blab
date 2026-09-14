# Offline history and photo recovery QA

Date: 2026-09-13

Environment: local Supabase, Alice in the Flutter web client, Bob in the Android emulator. No staging or production data was changed.

## Local fixtures

- Alice and Bob shared chat with one captionless legacy photo that has no preview metadata.
- Alice and Bob shared chat with one captionless modern photo whose preview and original are visibly different.
- Alice-only chat with Carol containing `Alice-only cache marker` for the account-isolation check.

## Matrix

| Case | Result | Evidence |
| --- | --- | --- |
| Cached preview remains visible offline after app restart | Pass | `screenshots/06-bob-previews-offline-after-restart.png` |
| Opened full photo opens offline from the bounded full-image cache | Pass | `screenshots/07-bob-opened-full-photo-offline.png` |
| Never-downloaded photo shows a neutral placeholder, then recovers after reconnection | Pass | `screenshots/08-bob-never-downloaded-placeholder-offline.png`, `screenshots/09-bob-photo-auto-recovered-online.png` |
| Damaged legacy photo does not hide or disable the conversation | Pass | `screenshots/10-bob-damaged-legacy-photo-offline.png` |
| Switching the same browser from Alice to Bob does not expose Alice-only history | Pass | `screenshots/11-alice-account-baseline.png`, `screenshots/12-bob-account-after-switch.png` |
| No cached history plus REST failure shows Retry; tapping Retry after REST recovery reloads the chat | Pass | `screenshots/13-bob-no-history-service-failure-retry.png`, `screenshots/14-bob-retry-reconnected.png` |

## Photo-caption language matrix

| Case | Result | Evidence |
| --- | --- | --- |
| Captionless photo creates no language warning | Pass | Existing recovery screenshots plus focused regression coverage |
| English caption is preserved for Alice while learning English | Pass | `screenshots/15-alice-photo-caption-english.png` |
| The same English caption is detected and translated into German for Bob | Pass | `screenshots/16-bob-english-caption-translated-to-german.png` |
| Supported German and Spanish captions are detected and translated into English | Pass | Alice browser matrix and stored translation records |
| Unsupported Chinese caption stays readable with one neutral unsupported-language hint and no Retry | Pass | `screenshots/17-alice-caption-language-matrix.png` |
| Emoji-only caption creates no translation request or warning | Pass | `screenshots/17-alice-caption-language-matrix.png` plus focused regression coverage |
| Photo and caption survive an offline restart | Pass | Bob Android offline restart |
| A previously completed caption translation remains visible during that offline restart | **Fail** | The photo and authored caption recover, but the learning-language translation currently requires the server after restart |
| Translation-provider failure keeps the photo/caption readable and exposes Retry | Pass | Bob Android Spanish-to-German failure state |
| Manual Retry always completes the Spanish-to-German result | **Environment-limited** | The local provider repeatedly failed its grammatical-form audit; the app retained the readable caption and Retry state |

## Notes and limitations

- The photo cache manipulations used only Bob's emulator-local preferences and the local QA backend.
- Both photo messages use an empty caption and create no translation-preparation job. The screenshot evidence was repeated after removing temporary fixture labels that had been interpreted as captions and produced misleading unsupported-language hints.
- Caption text follows the normal message-language pipeline; Blab does not OCR text drawn inside the image.
- Completed caption translations are server-cached but not yet included in the account-scoped device recovery cache, so offline restart falls back to the authored caption. This is tracked as launch follow-up L-26.
- The Spanish-to-German Retry limitation was attributed to the local provider's grammatical-form audit, not to photo upload, caption storage, or language detection.
- The account switch was exercised in one browser profile: Alice showed the Carol marker, while Bob showed only Alice.
- This pass does not claim reinstall/new-device recovery or physical-device coverage. The approved V1 contract keeps those out of scope.
- Owner acceptance remains separate from this engineering QA record.

## Automated verification

- `flutter analyze`: no issues.
- `flutter test`: 495 passed, 15 environment-gated skips.
- `scripts/local_test.sh integration`: 11 passed, 3 local-function/OpenRouter-gated skips.
- Focused history/cache recovery tests: 20 passed.
- Focused photo-caption display tests: 3 passed.
- `dart format --output=none --set-exit-if-changed lib test`, `bash -n scripts/*.sh`, and `git diff --check`: clean.
