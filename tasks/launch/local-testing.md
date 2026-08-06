# Local MVP Testing

The local environment is isolated from the linked Supabase project. Resetting it
deletes only local Blab data and recreates three deterministic test users.

## Start clean

Prerequisites: Docker Desktop, Supabase CLI, Flutter, and `jq`.

```bash
scripts/local_test.sh reset
```

Use this helper instead of running `supabase db reset` directly. The direct command
selects the unhealthy CLI-pinned Postgres image on this development machine; the
helper removes any failed local container and applies the compatible local image
override before resetting.

All three users share the local-only password `Blab-local-123!`:

| Role | Name | Email |
| --- | --- | --- |
| Account A | Alice Local | `alice@blab.test` |
| Account B | Bob Local | `bob@blab.test` |
| Account C | Carol Local | `carol@blab.test` |

Do not reuse these credentials outside local development.

## Run two clients

Use one terminal for Android:

```bash
scripts/local_test.sh android emulator-5554
```

If that emulator is not running, the helper starts the `Pixel_10_Pro` AVD and
waits for Android to finish booting. Override the AVD with
`BLAB_ANDROID_AVD=another_name` when needed.

Normal helper runs use Flutter debug mode and the app's normal initial route.
For a work item that must explicitly probe a route or release behavior, use the
opt-in overrides, for example:

```bash
BLAB_FLUTTER_MODE=release BLAB_INITIAL_ROUTE=/dev \
  scripts/local_test.sh android emulator-5554
```

Supported modes are `debug`, `profile`, and `release`. Do not use these overrides
for ordinary product-journey tests.

Use another terminal for Chrome when a two-user realtime test is needed:

```bash
scripts/local_test.sh web
```

Use the Chrome window opened by this command. A second tab in your normal Chrome
profile cannot attach to the same Flutter debug session and may remain blank.
To start a fresh Flutter Chrome session directly on an invite route, pass the
copied URL or token:

```bash
scripts/local_test.sh web '<copied-invite-url-or-token>'
```

The helper reads the local public API key from `supabase status` and supplies the
correct host URL for each platform. It also labels the build `local` and disables
Firebase initialization. Plain `flutter run` has no backend fallback and exits
before making a request; hosted runs require the guarded environment helper.

## Enable local translation

Translation runs in the local `translate-message` Edge Function, which needs its
own OpenRouter development key. Hosted Supabase secrets are write-only and are not
copied into the local stack.

Create `supabase/.env.local` with:

```dotenv
OPEN_ROUTER_KEY=<your-development-openrouter-key>
```

For Blab development, this must be the approved "OpenRouter API Key - Blab
Staging" value. Do not use OpenRouter keys from workspace env files, shell env,
`~/clawd/.env`, or unrelated project env files for Blab local functions,
translation QA, or provider tests.

The file is gitignored. Never commit or paste the key into task records. Then keep
the local functions server running in a separate terminal:

```bash
scripts/local_test.sh functions
```

Restart the app or reopen the chat after starting the function server. Translation
errors are cached in memory for the current app process, so hot reload alone does
not retry an entry that has already failed.

## Run backend integration

Run the opt-in invite/auth integration against the local Supabase stack:

```bash
scripts/local_test.sh integration
```

The test uses independent Supabase clients for Alice, Bob, Carol, and one
disposable sign-up identity. It verifies successful signup-to-claim membership,
a concurrent single-use claim, the losing account's exclusion, and expiry without
membership creation. Generated invites, chats, and the disposable user are removed
even when the test fails. The helper reads local-only keys from `supabase status`;
no service-role key is stored in the repository.

## L-01 realtime check

1. Run the Android and web commands above in separate terminals.
2. On Android, confirm the dev menu has no pair-by-email action, then sign in as
   Alice (Account A).
3. In Chrome, sign in as Bob (Account B).
4. On Android, open **Chats**, tap **Invite a friend** or the new-chat button, pick a language,
   tap **Continue**, then **Share invite** and **Copy link**.
5. In a third terminal, run `scripts/local_test.sh invite '<copied-url>'`, then
   paste the printed local URL into the Chrome window that the web helper opened.
   Pick Bob's learning language and accept the invite in Chrome. The invite
   helper intentionally does not open a normal browser tab because that tab is
   not attached to Flutter's debug session.
6. Keep both chat screens visible. Send `Hello from Bob` in Chrome and confirm it
   appears immediately on Android. Reply with `Hello from Alice` on Android and
   confirm it appears immediately in Chrome.
7. Reopen the chat on both clients and confirm both messages remain.

The backend integration gate separately verifies that Account C cannot insert a
chat, join Alice and Bob's chat, read its messages, or call the removed
pair-by-email RPC.

## Reset behavior

Running `scripts/local_test.sh reset` again removes local chats, messages, invites,
and sessions stored in the local database. The app may retain an expired local
session on-device; log out or clear app data after a reset before signing in again.

The helper currently uses Supabase Postgres `17.6.1.084` for local resets because
the CLI-pinned `17.6.1.127` image has a zero-byte entrypoint on this development
machine. It restores `supabase/.temp/postgres-version` after every run. Both images
use PostgreSQL 17.6; remote migration verification remains the deployment gate.
