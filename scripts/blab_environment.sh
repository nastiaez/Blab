#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

usage() {
  cat <<'USAGE'
Usage:
  scripts/blab_environment.sh validate <staging|production>
  scripts/blab_environment.sh run <staging|production> <device-id>
  scripts/blab_environment.sh build <staging|production>

Configuration is read from env/<environment>.json. Android Firebase
configuration is read from env/firebase/<environment>/google-services.json.

Running against production requires BLAB_CONFIRM_PRODUCTION=production.
USAGE
}

fail() {
  printf 'Environment validation failed: %s\n' "$1" >&2
  exit 2
}

action="${1:-}"
environment="${2:-}"
device="${3:-}"

case "$action" in
  validate | run | build) ;;
  *) usage; exit 2 ;;
esac
case "$environment" in
  staging | production) ;;
  *) usage; exit 2 ;;
esac

command -v jq >/dev/null || fail 'jq is required.'

config_file="env/$environment.json"
[[ -f "$config_file" ]] || fail "Missing $config_file. Start from config/environments/$environment.example.json."

required_fields=(
  BLAB_ENV
  SUPABASE_PROJECT_REF
  SUPABASE_URL
  SUPABASE_PUBLISHABLE_KEY
  GOOGLE_WEB_CLIENT_ID
  FIREBASE_PROJECT_ID
  SENTRY_DSN
  SENTRY_ENV
)
for field in "${required_fields[@]}"; do
  jq -e --arg field "$field" '
    has($field) and (.[$field] | type == "string")
  ' "$config_file" >/dev/null || fail "$field is missing from $config_file."
done

if jq -e '
  to_entries[] |
  select((.value | type) == "string") |
  select(.value | ascii_downcase | contains("replace_with"))
' "$config_file" >/dev/null; then
  fail "$config_file still contains a template placeholder."
fi

config_environment="$(jq -er '.BLAB_ENV' "$config_file")"
project_ref="$(jq -er '.SUPABASE_PROJECT_REF' "$config_file")"
supabase_url="$(jq -er '.SUPABASE_URL' "$config_file")"
publishable_key="$(jq -er '.SUPABASE_PUBLISHABLE_KEY' "$config_file")"
google_client_id="$(jq -er '.GOOGLE_WEB_CLIENT_ID' "$config_file")"
firebase_project_id="$(jq -er '.FIREBASE_PROJECT_ID' "$config_file")"
sentry_dsn="$(jq -er '.SENTRY_DSN' "$config_file")"
sentry_environment="$(jq -er '.SENTRY_ENV' "$config_file")"

[[ "$config_environment" == "$environment" ]] || fail 'BLAB_ENV does not match the selected environment.'
[[ "$sentry_environment" == "$environment" ]] || fail 'SENTRY_ENV does not match the selected environment.'
[[ "$supabase_url" == "https://$project_ref.supabase.co" ]] || fail 'SUPABASE_URL does not match SUPABASE_PROJECT_REF.'
[[ "$publishable_key" == sb_publishable_* || "$publishable_key" == eyJ* ]] || fail 'SUPABASE_PUBLISHABLE_KEY is malformed.'
[[ ${#publishable_key} -ge 40 ]] || fail 'SUPABASE_PUBLISHABLE_KEY is truncated.'
[[ "$google_client_id" == *.apps.googleusercontent.com ]] || fail 'GOOGLE_WEB_CLIENT_ID is malformed.'
[[ -n "$firebase_project_id" ]] || fail 'FIREBASE_PROJECT_ID is required.'

production_ref='bhzcexhebjszwyqvcsxs'
if [[ "$environment" == 'production' ]]; then
  [[ "$project_ref" == "$production_ref" ]] || fail 'Production project ref is not approved.'
  [[ "$sentry_dsn" == https://* ]] || fail 'Production SENTRY_DSN is required.'
else
  [[ "$project_ref" != "$production_ref" ]] || fail 'Staging cannot use the production project.'
fi

needs_android_config=0
if [[ "$action" == 'validate' || "$action" == 'build' || ( "$action" == 'run' && "$device" != 'chrome' ) ]]; then
  needs_android_config=1
fi
if [[ "$needs_android_config" == '1' ]]; then
  firebase_file="env/firebase/$environment/google-services.json"
  [[ -f "$firebase_file" ]] || fail "Missing $firebase_file."
  configured_firebase_project="$(jq -er '.project_info.project_id' "$firebase_file")"
  configured_package="$(jq -er '.client[0].client_info.android_client_info.package_name' "$firebase_file")"
  [[ "$configured_firebase_project" == "$firebase_project_id" ]] || fail 'Firebase file does not match FIREBASE_PROJECT_ID.'
  [[ "$configured_package" == 'blab.nastia.ez' ]] || fail 'Firebase Android package must be blab.nastia.ez.'
  cp "$firebase_file" android/app/google-services.json
fi

printf 'Validated %s environment configuration.\n' "$environment"

case "$action" in
  validate)
    ;;
  run)
    [[ -n "$device" ]] || fail 'A Flutter device ID is required.'
    if [[ "$environment" == 'production' && "${BLAB_CONFIRM_PRODUCTION:-}" != 'production' ]]; then
      fail 'Set BLAB_CONFIRM_PRODUCTION=production to run against production.'
    fi
    flutter run -d "$device" --dart-define-from-file="$config_file"
    ;;
  build)
    flutter build appbundle --release --dart-define-from-file="$config_file"
    ;;
esac
