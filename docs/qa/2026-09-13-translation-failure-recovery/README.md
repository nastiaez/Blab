# Translation failure recovery QA

Date: 2026-09-13

## Setup

- Alice Local: Flutter web in the managed browser
- Bob Local: Flutter app on Android emulator `emulator-5554`
- Local Supabase reset before acceptance
- Bob: English known language, German learning language, Practice mode

## Real-client acceptance

1. Alice sent `Can you please help me?`; Bob received `Kannst du mir bitte helfen?`.
2. Alice sent `Are you ready?`; Bob received `Bist du bereit?`.
3. Alice sent `你好，Bob!`; both clients showed the authored text with exactly `Blab doesn’t speak this one yet.`
4. The unsupported message showed no red translation error and no Retry action.
5. Bob's three preparation jobs reached `ready` with one attempt each. The saved German cache rows were `en`, `en`, and `other` for the three source messages.

## Screenshots

- `screenshots/01-bob-german-and-unsupported.png`: Bob's Android view proves both German translations and the unsupported-language notice.
- `screenshots/02-alice-outgoing-unsupported.png`: Alice's browser view proves the same exact notice for her outgoing unsupported message.

## Automated verification

- Flutter: 476 passed, 15 integration skips
- Deno edge functions and worker: 104 passed
- Database: 140 passed
- Static analysis: clean
- Relevant formatting and diff checks: clean
