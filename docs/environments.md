# Blab environments

Blab has three isolated environments. The app has no default hosted backend:
every hosted run or build must select one explicitly.

| Environment | Purpose | Supabase | Firebase | Sentry |
| --- | --- | --- | --- | --- |
| Local | Daily development and destructive tests | Local CLI stack | Disabled | Disabled |
| Staging | Release-candidate and integration checks | `Blab Staging` | Separate staging project | Staging environment |
| Production | Play releases and production verification | Existing production project | Production project | Production environment |

## Local

```bash
scripts/local_test.sh reset
scripts/local_test.sh android emulator-5554
scripts/local_test.sh web
```

The helper obtains the local public key from `supabase status`. It never reads a
hosted environment file and never initializes Firebase.

## Hosted app configuration

Create ignored files from the tracked templates:

```bash
mkdir -p env/firebase/staging env/firebase/production
cp config/environments/staging.example.json env/staging.json
cp config/environments/production.example.json env/production.json
```

Fill each JSON file with that environment's public client configuration. Keep
the matching Android Firebase file at:

```text
env/firebase/staging/google-services.json
env/firebase/production/google-services.json
```

These files are ignored because they are deployment inputs, even though the
Supabase publishable key, OAuth client ID, Firebase project ID, and Sentry DSN
are shipped in the compiled client. Never place a service-role key, OpenRouter
key, Firebase service-account private key, webhook secret, or Sentry auth token
in either JSON file.

Validate before running:

```bash
scripts/blab_environment.sh validate staging
scripts/blab_environment.sh validate production
```

Run staging on Android:

```bash
scripts/blab_environment.sh run staging emulator-5554
```

Production runs require an additional deliberate confirmation:

```bash
BLAB_CONFIRM_PRODUCTION=production \
  scripts/blab_environment.sh run production emulator-5554
```

Build the Play bundle only through the guarded helper:

```bash
scripts/blab_environment.sh build production
```

## Backend configuration

The checked manifests in `config/deployments/` define each Supabase project,
region, deployed function JWT policy, and required secret names. Verify either
hosted backend without reading secret values:

```bash
scripts/verify_backend.sh staging
scripts/verify_backend.sh production
```

The verifier temporarily links the selected project and restores the previous
link when it exits. A failed check is deployment drift, not a reason to bypass
the manifest.

Hosted provider secrets are set directly in their matching Supabase project.
Use a separate OpenRouter key and Firebase service account for staging. Keep
owner copies in 1Password and never copy production secrets into local files.

## Release gate

A production candidate is valid only when all of these agree:

- `env/production.json` selects the approved production Supabase and Firebase
  project IDs and uses `SENTRY_ENV=production`.
- `env/firebase/production/google-services.json` belongs to package
  `blab.nastia.ez` and the configured production Firebase project.
- `scripts/verify_backend.sh production` passes.
- The signed AAB is built with `scripts/blab_environment.sh build production`.

Staging accounts, sessions, messages, device tokens, translations, and logs are
separate from production. Do not expect an account created in one environment
to sign in to another.
