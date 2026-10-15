# Blab Test operator runbook (candidate, not deployed)

## Release prerequisites

After owner approval of screenshots/workflow, provision a dedicated test Supabase project and Firebase Android app `blab.nastia.ez.test`. Never repurpose the public project. Apply all migrations; verify project identity before any policy mutation. The migration deliberately defaults to public for backward compatibility: configure the new isolated project as test before distributing any client or admitting testers.

Configure staging with `BLAB_APP_CHANNEL=test`, the separate project URL/public key, test Firebase configuration and auth callbacks using `blab-test`. Do not put administrative credentials in the app. Build/sign the integrated main revision and verify side-by-side installation with public Blab. Deploy `/i-test/` landing and Android asset associations; test normal OS link resolution (not only explicit activity intents), authentication continuation and cold starts with the signed downloaded artifact. iOS is not implemented by this slice.

## Trusted server administration only

Run these only in the independently verified **test** project's privileged SQL console. The public client cannot edit these tables. First initialize this fresh test project while closed:

```sql
update public.app_distribution_policy
set channel = 'test', testing_enabled = false
where singleton;
```

After a participant creates a test account, verify its UUID against the approved participant roster. Firebase invitation email alone is not app authorization. Add the verified UUID with a chosen explicit expiry:

```sql
insert into public.test_app_members (user_id, enabled, expires_at)
values ('<verified-test-account-uuid>'::uuid, true, '<chosen-expiry-ISO8601>'::timestamptz)
on conflict (user_id) do update
set enabled = excluded.enabled, expires_at = excluded.expires_at;
```

Open the session after setting the intended expiry:

```sql
update public.app_distribution_policy
set testing_enabled = true, testing_expires_at = '<chosen-expiry-ISO8601>'::timestamptz
where singleton and channel = 'test';
```

Master kill switch:

```sql
update public.app_distribution_policy set testing_enabled = false
where singleton and channel = 'test';
```

Individual revocation:

```sql
update public.test_app_members set enabled = false
where user_id = '<verified-test-account-uuid>'::uuid;
```

Re-enable using the same explicit policy/member controls, checking both expiry values. Do not silently extend an expired session. Keep an operator change receipt with project, timestamp, actor, affected cohort/user, and previous/new values; never include credentials.

## Behavior and limits

- The server rejects newly authorized chat reads/writes/invites when access is disabled. Test UI checks on entry/resume and every 15 seconds; failed checks hide protected content.
- Re-enabling reloads the chat list; Android recovery was verified without restarting.
- Public Blab accounts/history are separate and unchanged. No automatic account/data migration, subscription entitlement or billing changes.
- This is an account/project boundary, not proof of an authentic binary. Approved test credentials must still be protected.
- Downloaded data/screenshots cannot be remotely erased. Previously issued media links may work until expiry; offline devices cannot receive immediate revocation.
- Unapproved accounts cannot create/claim chats. A forwarded APK or link does not enroll its recipient.
