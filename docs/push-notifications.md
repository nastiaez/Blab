# Android push notification setup

L-17 uses Firebase Cloud Messaging (FCM) for Android system notifications and
a Supabase Database Webhook plus the `send-push` Edge Function for delivery.
No Firebase or service-account secrets belong in Git.

## 1. Create the Firebase Android app

1. In Firebase Console, create or select the matching staging or production
   project.
2. Add an Android app with package name `blab.nastia.ez`.
3. Download `google-services.json` and place it at
   `env/firebase/<environment>/google-services.json`. The guarded environment
   helper validates and copies it into the gitignored Android build location.

Local Android runs disable Firebase and do not register a production token:

```bash
scripts/local_test.sh android emulator-5554
```

Run staging or build production with its matching configuration:

```bash
scripts/blab_environment.sh run staging emulator-5554
scripts/blab_environment.sh build production
```

## 2. Configure server credentials

1. In **Firebase Project settings → Service accounts**, generate a private
   service-account key. Store the downloaded JSON in 1Password and do not put
   it in this repository.
2. Generate a random webhook secret with at least 32 characters.
3. Create an environment-specific, gitignored Edge Function env file such as
   `supabase/.env.push.staging` or `supabase/.env.push.production`:

```dotenv
FIREBASE_PROJECT_ID=<project_id>
FIREBASE_CLIENT_EMAIL=<client_email_from_service_account_json>
FIREBASE_PRIVATE_KEY="<private_key_from_service_account_json>"
PUSH_WEBHOOK_SECRET=<random_secret>
```

4. Link the Supabase CLI to the matching project, then install the secrets and
   deploy. Confirm the project ref before running these commands:

```bash
supabase secrets set --env-file supabase/.env.push.<environment>
supabase db push
supabase functions deploy send-push --no-verify-jwt
```

The service-account JSON remains only in 1Password. After extracting the three
needed values, remove any unencrypted local copy.

## 3. Create the asynchronous webhook

Migration `20260720000002_push_notification_webhook.sql` creates the
asynchronous `pg_net` trigger. Provision these two encrypted Supabase Vault
secrets separately from migrations and source control:

- `blab_push_webhook_url`: the deployed `send-push` Edge Function URL
- `blab_push_webhook_secret`: the same `PUSH_WEBHOOK_SECRET` value installed on
  the Edge Function

The trigger does nothing when either Vault value is absent or invalid. It also
catches dispatch errors so push infrastructure cannot roll back app writes.

The database transaction only inserts an outbox event. The webhook runs after
commit, so FCM failure cannot fail or roll back a message or invite claim.

## 4. Operational checks

- Confirm app clients receive permission errors when selecting
  `push_device_tokens`, `push_notification_events`, or delivery rows.
- Confirm the webhook receives one event for a message and one for a claimed
  invite.
- Confirm previews ON sends sender plus original message only. Previews OFF
  sends generic copy. Neither payload may contain translations or email.
- On an FCM `UNREGISTERED` response, confirm the stale token row is deleted.
- To disable push without an app release, remove either Blab push Vault secret
  or disable the `send_push_notification_event` database trigger first.
  To purge routing data, delete all rows from `push_device_tokens` using the
  Supabase service role.

Production credential deployment and physical-device evidence are recorded in
the L-17/L-18 launch work records.
