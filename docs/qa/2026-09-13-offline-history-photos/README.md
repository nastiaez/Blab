# Offline history and photo recovery QA

Date: 2026-09-13

Environment: local Supabase, Alice in the Flutter web client, Bob in the Android emulator. No staging or production data was changed.

## Local fixtures

- Alice and Bob shared chat with one legacy photo that has no preview metadata.
- Alice and Bob shared chat with one modern photo whose preview and original are visibly different.
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

## Notes and limitations

- The photo cache manipulations used only Bob's emulator-local preferences and the local QA backend.
- The account switch was exercised in one browser profile: Alice showed the Carol marker, while Bob showed only Alice.
- This pass does not claim reinstall/new-device recovery or physical-device coverage. The approved V1 contract keeps those out of scope.
- Owner acceptance remains separate from this engineering QA record.

## Automated verification

- `flutter analyze`: no issues.
- `flutter test`: 489 passed, 15 environment-gated skips.
- `scripts/local_test.sh integration`: 11 passed, 3 local-function/OpenRouter-gated skips.
- Focused history/cache recovery tests: 20 passed.
- `dart format --output=none --set-exit-if-changed lib test`, `bash -n scripts/*.sh`, and `git diff --check`: clean.
