<p align="center">
  <img src="assets/blab-logo.svg" alt="Blab" width="180">
</p>

# Blab

A language-exchange chat app where two people swap their native languages by chatting.

You teach what you speak. You learn what they speak. Built in [Flutter](https://flutter.dev), Android-first.

## Idea

You speak Ukrainian and want to learn Tamil. Aswin speaks Tamil and wants to learn Ukrainian. You send him an invite link, he joins, you start chatting. Both of you write in whichever language feels natural; the bubble shows the other language too. Tap any word to see how it's pronounced and what it means.

Invite-only. No discovery, no public profiles, no analytics.

## Privacy posture

- No analytics. No ads. No selling data.
- End-to-end encryption on message content is a hard gate before any external tester sees the app (in progress, [Step 2.6](./tasks/progress.md)).
- Read receipts and typing indicators are symmetric on/off toggles (Signal-style) — turn yours off and you stop seeing your partner's too.

## Stack

- **Flutter** (Dart 3+), Android-first, iOS later.
- **Riverpod 3** for state.
- **Supabase** for auth (email + Google), Postgres + RLS for storage, Realtime for live message sync, Edge Functions for privileged ops.
- **`go_router`** for navigation.
- System fonts. Brand color `#5B4FE8` (long-term identity color `#D4694A`).

## Repo layout

```
lib/
  app/                  router, theme, dev menu, app messenger
  features/
    auth/               sign up, log in, forgot/reset password
    chats/              chat list + tile + bottom tabs
    chat/               chat view + bubbles + word popups + read state
    invite/             new chat, share sheet, invite landing
    profile/            profile, edit, change email/password, privacy, delete
  shared/
    data/               languages, supabase config, row→model mappers
    models/             Chat, Message, MessageToken
    services/           ChatService, SupabaseAuthService, TtsService
    state/              auth, chat-list, interface-language, privacy, etc.
    widgets/            shared UI (skeletons, offline banner, …)
supabase/
  migrations/           Postgres schema, RLS, RPCs, views
  functions/            edge functions (delete-account, …)
tasks/
  prd-blab.md           product spec — the canonical "what"
  tech-spec.md          tech spec — the canonical "how"
  progress.md           build plan — the canonical "when"
docs/                   superpowers scratch (specs, plans, baselines)
prototype.html          static interaction prototype (open in any browser)
```

`tasks/prd-blab.md`, `tasks/tech-spec.md`, and `tasks/progress.md` are the source of truth. PRD wins on product behavior; tech-spec wins on engineering choices; progress wins on order of work.

## Local development

### Prerequisites

- Flutter `3.44.4` and a working `flutter doctor` installation.
- Supabase CLI `2.109.1`, Docker Desktop, and `jq`.
- Chrome for web development.
- Android Studio, an Android SDK, and an Android emulator for Android work.

From the repository root, resolve dependencies:

```bash
cd /path/to/Blab
flutter pub get
```

For local AI translation, create the ignored function environment file if it
does not already exist, then add a development-only OpenRouter key:

```bash
test -f supabase/.env.local || cp supabase/.env.example supabase/.env.local
```

```dotenv
OPEN_ROUTER_KEY=<development-key>
```

Never commit `supabase/.env.local` or put production provider credentials in it.
For Blab work, always use the approved "OpenRouter API Key - Blab Staging" value
as `OPEN_ROUTER_KEY` in `supabase/.env.local`. Do not use OpenRouter keys from
workspace env files, shell env, `~/clawd/.env`, or unrelated project env files
for Blab functions, translation QA, or provider tests. If a hotfix worktree has
its own `supabase/.env.local`, copy the same approved Blab key there before
starting `scripts/local_test.sh functions`.

### Start the local backend

Run this once before launching clients, and again whenever migrations or seed
data need to be reapplied:

```bash
scripts/local_test.sh reset
```

This is destructive to local Blab data. It rebuilds the local Supabase database,
applies every migration, seeds connected Alice/Bob test data, and prints the
available accounts. It never touches staging or production.

### Run the clients

Keep each command running in its own terminal window.

Terminal 1, local Edge Functions for translation:

```bash
cd /path/to/Blab
scripts/local_test.sh functions
```

Terminal 2, Flutter web:

```bash
cd /path/to/Blab
scripts/local_test.sh web
```

Chrome opens at `http://localhost:7357/`.

Terminal 3, Android emulator:

```bash
cd /path/to/Blab
scripts/local_test.sh android emulator-5554
```

Start the emulator from Android Studio's Device Manager first. If its ID is not
`emulator-5554`, find the correct ID and substitute it in the command:

```bash
flutter devices
```

Use `r` for hot reload, `R` for hot restart, and `q` to stop a Flutter process.
Plain `flutter run` intentionally fails without explicit environment values, so
it cannot silently connect to production.

### Local test accounts

All seeded accounts use the same password: `Blab-local-123!`.

| Account | Email | Suggested client |
| --- | --- | --- |
| Alice | `alice@blab.test` | Web |
| Bob | `bob@blab.test` | Android |
| Carol | `carol@blab.test` | Authorization/edge-case tests |

Print the account list at any time:

```bash
scripts/local_test.sh accounts
```

### Invite testing

Launch a fresh web session directly into an invite by passing either the copied
URL or its token:

```bash
scripts/local_test.sh web 'https://blab-gray.vercel.app/i/<invite-token>'
```

To print the equivalent local URL without launching another client:

```bash
scripts/local_test.sh invite 'https://blab-gray.vercel.app/i/<invite-token>'
```

### Test fixtures

Seed up to 500 older messages into an existing Alice/Bob chat:

```bash
scripts/local_test.sh history 120
```

Force or clear the local translation quota state for an account:

```bash
scripts/local_test.sh translation-limit set alice
scripts/local_test.sh translation-limit clear alice
```

### Automated verification

Run the ordinary source and Flutter gates:

```bash
dart format --output=none --set-exit-if-changed lib test
bash -n scripts/*.sh
flutter analyze
flutter test
git diff --check
```

Generate the same coverage report retained by CI:

```bash
flutter test --coverage
```

Rebuild the disposable backend and run Realtime plus database authorization,
invite, messaging, moderation, push-outbox, and translation-security tests:

```bash
scripts/local_test.sh reset
scripts/local_test.sh integration
```

The provider-backed translation cases are skipped unless explicitly enabled
with a development OpenRouter key; all secretless database contracts still run.

GitHub Actions runs these gates on every pull request and also compiles a
non-distributable Android release AAB with temporary CI-only signing and Firebase
configuration. See [`.github/workflows/ci.yml`](./.github/workflows/ci.yml).

### Staging and production

Hosted staging and production use ignored build configuration files and guarded
commands. Do not substitute hosted URLs or keys into the local commands above.
See [`docs/environments.md`](./docs/environments.md) for validation, hosted app
runs, backend drift checks, and release builds.

Android push notifications additionally require the owner-controlled Firebase
and Supabase setup in [`docs/push-notifications.md`](./docs/push-notifications.md).

## Status

| Phase | What | State |
|---|---|---|
| Phase 0 | Foundations (Flutter, theme, routing) | done |
| Phase 1 | Static UI (auth, chats, chat view, invite, profile) | done |
| Phase 2.1 | Auth backend (Supabase, Google SSO, delete account) | done (Android; Apple SSO pending iOS phase) |
| Phase 2.2 | Chat persistence + real-time sync + read receipts | done |
| Phase 2.3 | Real invite links (single-use, 48h TTL) | next |
| Phase 2.4 | Send-failure + offline queue | partial (UI wired, edge cases pending) |
| Phase 2.5 | Push notifications (FCM) | production deployed; physical-device verification pending |
| Phase 2.6 | End-to-end encryption (hard gate before external testers) | not started |
| Phase 3 | iOS parity + release prep | not started |

See [`tasks/progress.md`](./tasks/progress.md) for the live build plan.

## License

Not yet published. All rights reserved while in development.
