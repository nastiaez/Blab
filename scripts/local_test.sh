#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

password='Blab-local-123!'
postgres_version_file='supabase/.temp/postgres-version'
local_postgres_version="${BLAB_LOCAL_POSTGRES_VERSION:-17.6.1.084}"
supported_supabase_cli_version="${BLAB_SUPABASE_CLI_VERSION:-2.109.1}"
function_env_file="${BLAB_FUNCTION_ENV_FILE:-supabase/.env.local}"

require_supported_supabase_cli() {
  local actual
  actual="$(supabase --version)"
  if [[ "$actual" == "$supported_supabase_cli_version" ]]; then
    return
  fi

  printf '%s\n' \
    "Unsupported Supabase CLI: $actual." \
    "Blab local tests currently require $supported_supabase_cli_version." \
    'Use BLAB_SUPABASE_CLI_VERSION only after verifying reset and integration.' >&2
  exit 1
}

print_accounts() {
  printf '%s\n' \
    'Local Blab accounts (all use the same password):' \
    '  A / Alice: alice@blab.test' \
    '  B / Bob:   bob@blab.test' \
    '  C / Carol: carol@blab.test' \
    "  Password:  $password"
}

invite_token() {
  local input="${1:-}"
  local token
  if [[ -z "$input" ]]; then
    printf 'Paste the copied invite URL or token as the second argument.\n' >&2
    exit 2
  fi

  token="${input##*/}"
  token="${token%%\?*}"
  token="${token%%\#*}"
  if [[ -z "$token" ]]; then
    printf 'Could not extract an invite token from: %s\n' "$input" >&2
    exit 2
  fi

  printf '%s' "$token"
}

print_web_invite() {
  local input="${1:-}"
  local token
  token="$(invite_token "$input")"

  local url="http://localhost:7357/#/i/$token"
  printf '%s\n' \
    'Paste this URL into the Chrome window launched by the web helper:' \
    "  $url" \
    '' \
    'To launch a fresh web session directly on the invite instead:' \
    "  scripts/local_test.sh web '$input'"
}

status_json() {
  supabase status -o json
}

local_key() {
  status_json | jq -er '.PUBLISHABLE_KEY // .ANON_KEY'
}

run_integration() {
  local status
  local api_url
  local publishable_key
  local service_role_key
  local integration_target="${BLAB_INTEGRATION_TARGET:-test/integration}"

  require_supported_supabase_cli
  status="$(status_json)"
  api_url="$(printf '%s' "$status" | jq -er '.API_URL')"
  publishable_key="$(printf '%s' "$status" | jq -er '.PUBLISHABLE_KEY // .ANON_KEY')"
  service_role_key="$(printf '%s' "$status" | jq -er '.SERVICE_ROLE_KEY')"

  if [[ "${BLAB_RUN_OPENROUTER_INTEGRATION:-0}" == '1' ]]; then
    flutter test test/integration/local_translation_security_test.dart \
      --concurrency=1 \
      --dart-define=RUN_LOCAL_SUPABASE_INTEGRATION=true \
      --dart-define=RUN_LOCAL_OPENROUTER_INTEGRATION=true \
      --dart-define=BLAB_ENV=local \
      --dart-define=SUPABASE_PROJECT_REF=local \
      --dart-define=SENTRY_ENV=local \
      --dart-define="SUPABASE_URL=$api_url" \
      --dart-define="SUPABASE_PUBLISHABLE_KEY=$publishable_key" \
      --dart-define="SUPABASE_SERVICE_ROLE_KEY=$service_role_key"
  else
    flutter test test/local_readiness/realtime_ready_test.dart \
      --concurrency=1 \
      --dart-define=RUN_LOCAL_SUPABASE_INTEGRATION=true \
      --dart-define=BLAB_ENV=local \
      --dart-define=SUPABASE_PROJECT_REF=local \
      --dart-define=SENTRY_ENV=local \
      --dart-define="SUPABASE_URL=$api_url" \
      --dart-define="SUPABASE_PUBLISHABLE_KEY=$publishable_key" \
      --dart-define="SUPABASE_SERVICE_ROLE_KEY=$service_role_key"
    flutter test "$integration_target" \
      --concurrency=1 \
      --dart-define=RUN_LOCAL_SUPABASE_INTEGRATION=true \
      --dart-define=BLAB_ENV=local \
      --dart-define=SUPABASE_PROJECT_REF=local \
      --dart-define=SENTRY_ENV=local \
      --dart-define="SUPABASE_URL=$api_url" \
      --dart-define="SUPABASE_PUBLISHABLE_KEY=$publishable_key" \
      --dart-define="SUPABASE_SERVICE_ROLE_KEY=$service_role_key"
  fi
}

set_translation_limit() {
  local action="${1:-set}"
  local account="${2:-alice}"
  local user_id
  local status
  local rest_url
  local service_role_key

  case "$account" in
    alice) user_id='00000000-0000-4000-8000-00000000000a' ;;
    bob) user_id='00000000-0000-4000-8000-00000000000b' ;;
    carol) user_id='00000000-0000-4000-8000-00000000000c' ;;
    *)
      printf 'Use alice, bob, or carol.\n' >&2
      exit 2
      ;;
  esac

  status="$(status_json)"
  rest_url="$(printf '%s' "$status" | jq -er '.REST_URL')"
  service_role_key="$(printf '%s' "$status" | jq -er '.SERVICE_ROLE_KEY')"

  if [[ "$action" == 'clear' ]]; then
    curl -fsS -X DELETE \
      "$rest_url/translation_usage?user_id=eq.$user_id" \
      -H "apikey: $service_role_key" \
      -H "Authorization: Bearer $service_role_key"
    printf 'Cleared the local translation quota fixture for %s.\n' "$account"
    return
  fi
  if [[ "$action" != 'set' ]]; then
    printf 'Use set or clear.\n' >&2
    exit 2
  fi

  curl -fsS -X POST \
    "$rest_url/translation_usage?on_conflict=user_id" \
    -H "apikey: $service_role_key" \
    -H "Authorization: Bearer $service_role_key" \
    -H 'Content-Type: application/json' \
    -H 'Prefer: resolution=merge-duplicates,return=minimal' \
    --data "{\"user_id\":\"$user_id\",\"minute_started_at\":\"$(date -u '+%Y-%m-%dT%H:%M:00Z')\",\"minute_requests\":0,\"day_started_at\":\"$(date -u '+%Y-%m-%d')\",\"day_requests\":200,\"day_characters\":1000}"
  printf 'Set %s at the local daily translation limit.\n' "$account"
}

seed_history() {
  local count="${1:-120}"
  local alice_id='00000000-0000-4000-8000-00000000000a'
  local bob_id='00000000-0000-4000-8000-00000000000b'
  local status
  local api_url
  local rest_url
  local publishable_key
  local service_role_key
  local alice_token
  local bob_token
  local alice_language
  local bob_language
  local alice_temporary_language
  local bob_temporary_language
  local members
  local chat_id
  local payload

  if [[ ! "$count" =~ ^[0-9]+$ ]] || (( count < 1 || count > 500 )); then
    printf 'History count must be an integer from 1 to 500.\n' >&2
    exit 2
  fi

  status="$(status_json)"
  api_url="$(printf '%s' "$status" | jq -er '.API_URL')"
  rest_url="$(printf '%s' "$status" | jq -er '.REST_URL')"
  publishable_key="$(printf '%s' "$status" | jq -er '.PUBLISHABLE_KEY // .ANON_KEY')"
  service_role_key="$(printf '%s' "$status" | jq -er '.SERVICE_ROLE_KEY')"
  members="$(curl -fsS \
    "$rest_url/chat_members?select=chat_id,user_id,learning_language&user_id=in.($alice_id,$bob_id)" \
    -H "apikey: $service_role_key" \
    -H "Authorization: Bearer $service_role_key")"
  chat_id="$(printf '%s' "$members" | jq -r \
    --arg alice "$alice_id" \
    --arg bob "$bob_id" \
    'group_by(.chat_id) | map(select((map(.user_id) | index($alice)) and (map(.user_id) | index($bob)))) | first[0].chat_id // empty')"

  if [[ -z "$chat_id" ]]; then
    printf '%s\n' \
      'No local Alice/Bob chat exists.' \
      'Create one through an invite, then rerun this command.' >&2
    exit 1
  fi

  alice_language="$(printf '%s' "$members" | jq -er \
    --arg chat_id "$chat_id" --arg user_id "$alice_id" \
    '.[] | select(.chat_id == $chat_id and .user_id == $user_id) | .learning_language')"
  bob_language="$(printf '%s' "$members" | jq -er \
    --arg chat_id "$chat_id" --arg user_id "$bob_id" \
    '.[] | select(.chat_id == $chat_id and .user_id == $user_id) | .learning_language')"
  alice_temporary_language="$([[ "$alice_language" == 'es' ]] && printf 'de' || printf 'es')"
  bob_temporary_language="$([[ "$bob_language" == 'es' ]] && printf 'de' || printf 'es')"

  alice_token="$(curl -fsS -X POST \
    "$api_url/auth/v1/token?grant_type=password" \
    -H "apikey: $publishable_key" \
    -H 'Content-Type: application/json' \
    --data "{\"email\":\"alice@blab.test\",\"password\":\"$password\"}" \
    | jq -er '.access_token')"
  bob_token="$(curl -fsS -X POST \
    "$api_url/auth/v1/token?grant_type=password" \
    -H "apikey: $publishable_key" \
    -H 'Content-Type: application/json' \
    --data "{\"email\":\"bob@blab.test\",\"password\":\"$password\"}" \
    | jq -er '.access_token')"

  payload="$(jq -cn \
    --arg chat_id "$chat_id" \
    --arg alice "$alice_id" \
    --argjson count "$count" \
    '[range(1; $count + 1) | {
      chat_id: $chat_id,
      sender_id: $alice,
      body: ("L-16 history message " + (.|tostring)),
      created_at: ((1577836800 + .) | strftime("%Y-%m-%dT%H:%M:%SZ"))
    }]')"

  curl -fsS -X POST \
    "$rest_url/messages" \
    -H "apikey: $publishable_key" \
    -H "Authorization: Bearer $alice_token" \
    -H 'Content-Type: application/json' \
    -H 'Prefer: return=minimal' \
    --data "$payload"

  # Advance each member's translation era after inserting the old fixture.
  # The schema intentionally owns cutoff writes through language changes.
  curl -fsS -X PATCH \
    "$rest_url/chat_members?chat_id=eq.$chat_id&user_id=eq.$alice_id" \
    -H "apikey: $publishable_key" \
    -H "Authorization: Bearer $alice_token" \
    -H 'Content-Type: application/json' \
    -H 'Prefer: return=minimal' \
    --data "{\"learning_language\":\"$alice_temporary_language\"}"
  curl -fsS -X PATCH \
    "$rest_url/chat_members?chat_id=eq.$chat_id&user_id=eq.$alice_id" \
    -H "apikey: $publishable_key" \
    -H "Authorization: Bearer $alice_token" \
    -H 'Content-Type: application/json' \
    -H 'Prefer: return=minimal' \
    --data "{\"learning_language\":\"$alice_language\"}"
  curl -fsS -X PATCH \
    "$rest_url/chat_members?chat_id=eq.$chat_id&user_id=eq.$bob_id" \
    -H "apikey: $publishable_key" \
    -H "Authorization: Bearer $bob_token" \
    -H 'Content-Type: application/json' \
    -H 'Prefer: return=minimal' \
    --data "{\"learning_language\":\"$bob_temporary_language\"}"
  curl -fsS -X PATCH \
    "$rest_url/chat_members?chat_id=eq.$chat_id&user_id=eq.$bob_id" \
    -H "apikey: $publishable_key" \
    -H "Authorization: Bearer $bob_token" \
    -H 'Content-Type: application/json' \
    -H 'Prefer: return=minimal' \
    --data "{\"learning_language\":\"$bob_language\"}"

  printf 'Added %s pre-cutoff local history messages to Alice/Bob chat %s.\n' \
    "$count" "$chat_id"
}

serve_functions() {
  if [[ ! -f "$function_env_file" ]]; then
    printf '%s\n' \
      "Missing local function secrets file: $function_env_file" \
      'Create it with this entry, using a development OpenRouter key:' \
      '  OPEN_ROUTER_KEY=<your-development-key>' \
      '' \
      'The file is gitignored and must never be committed.' >&2
    exit 2
  fi

  if ! grep -Eq '^OPEN_ROUTER_KEY=.+$' "$function_env_file"; then
    printf 'OPEN_ROUTER_KEY is missing or empty in %s.\n' \
      "$function_env_file" >&2
    exit 2
  fi

  supabase functions serve --env-file "$function_env_file"
}

ensure_android_device() {
  local device="$1"
  local sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
  local adb="$sdk_root/platform-tools/adb"
  local emulator="$sdk_root/emulator/emulator"
  local avd="${BLAB_ANDROID_AVD:-Pixel_10_Pro}"
  local log_file="${TMPDIR:-/tmp}/blab-android-emulator.log"

  if [[ ! -x "$adb" || ! -x "$emulator" ]]; then
    printf 'Android SDK tools were not found under %s.\n' "$sdk_root" >&2
    exit 2
  fi
  if [[ "$("$adb" -s "$device" get-state 2>/dev/null || true)" == 'device' ]]; then
    return
  fi

  printf 'Starting Android AVD %s...\n' "$avd"
  if command -v launchctl >/dev/null 2>&1; then
    launchctl remove sh.aswin.blab-emulator >/dev/null 2>&1 || true
    launchctl submit -l sh.aswin.blab-emulator \
      -o "$log_file" -e "$log_file" -- "$emulator" -avd "$avd"
  else
    nohup "$emulator" -avd "$avd" </dev/null >"$log_file" 2>&1 &
  fi

  for ((attempt = 1; attempt <= 120; attempt++)); do
    if [[ "$("$adb" -s "$device" get-state 2>/dev/null || true)" == 'device' ]] &&
      [[ "$("$adb" -s "$device" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)" == '1' ]]; then
      printf 'Android emulator is ready.\n'
      return
    fi
    sleep 2
  done

  printf 'Android emulator did not boot within 4 minutes. Log: %s\n' "$log_file" >&2
  exit 1
}

run_app() {
  local device="$1"
  local invite_input="${2:-}"
  local flutter_mode="${BLAB_FLUTTER_MODE:-debug}"
  local initial_route="${BLAB_INITIAL_ROUTE:-}"
  local publishable_key
  local url
  local launch_url=''

  if ! publishable_key="$(local_key)"; then
    printf '%s\n' \
      'Local Supabase is not ready, so the app was not launched.' \
      'Run scripts/local_test.sh reset, then retry this command.' >&2
    return 1
  fi

  set -- flutter run

  case "$flutter_mode" in
    debug)
      ;;
    profile | release)
      set -- "$@" "--$flutter_mode"
      ;;
    *)
      printf 'Unsupported BLAB_FLUTTER_MODE: %s\n' "$flutter_mode" >&2
      printf 'Use debug, profile, or release.\n' >&2
      exit 2
      ;;
  esac
  if [[ -n "$initial_route" ]]; then
    set -- "$@" "--route=$initial_route"
  fi
  case "$device" in
    chrome)
      url='http://127.0.0.1:54321'
      ;;
    emulator-*)
      url='http://10.0.2.2:54321'
      ;;
    *)
      printf 'Unsupported device: %s\n' "$device" >&2
      printf 'Use chrome or an Android emulator id such as emulator-5554.\n' >&2
      exit 2
      ;;
  esac

  if [[ "$device" == 'chrome' ]]; then
    launch_url='http://localhost:7357/'
    if [[ -n "$invite_input" ]]; then
      launch_url="http://localhost:7357/#/i/$(invite_token "$invite_input")"
    fi
    "$@" -d chrome --web-port 7357 \
      --web-launch-url="$launch_url" \
      --dart-define=BLAB_ENV=local \
      --dart-define=SUPABASE_PROJECT_REF=local \
      --dart-define=SENTRY_ENV=local \
      --dart-define="SUPABASE_URL=$url" \
      --dart-define="SUPABASE_PUBLISHABLE_KEY=$publishable_key"
  else
    "$@" -d "$device" \
      --dart-define=BLAB_ENV=local \
      --dart-define=SUPABASE_PROJECT_REF=local \
      --dart-define=SENTRY_ENV=local \
      --dart-define="SUPABASE_URL=$url" \
      --dart-define="SUPABASE_PUBLISHABLE_KEY=$publishable_key"
  fi
}

reset_local() {
  local original_postgres_version=''
  local had_original_postgres_version='false'

  require_supported_supabase_cli
  if [[ -f "$postgres_version_file" ]]; then
    original_postgres_version="$(cat "$postgres_version_file")"
    had_original_postgres_version='true'
  fi

  restore_postgres_version() {
    if [[ "$had_original_postgres_version" == 'true' ]]; then
      printf '%s' "$original_postgres_version" > "$postgres_version_file"
    else
      rm -f "$postgres_version_file"
    fi
  }
  trap restore_postgres_version EXIT

  # Recover when a direct reset left the pinned image's database container
  # unhealthy. Reset is intentionally destructive to local Blab data.
  supabase stop --no-backup

  # The currently CLI-pinned 17.6.1.127 image has a zero-byte entrypoint on
  # this development machine. Use the verified compatible PG 17.6 image for
  # local resets without changing the repository's tracked CLI metadata.
  mkdir -p "$(dirname "$postgres_version_file")"
  printf '%s' "$local_postgres_version" > "$postgres_version_file"
  if [[ "${SUPABASE_DEBUG:-0}" == '1' ]]; then
    if [[ "${BLAB_IGNORE_SUPABASE_HEALTH_CHECKS:-0}" == '1' ]]; then
      supabase start --ignore-health-check --debug
    else
      supabase start --debug
    fi
    supabase db reset --debug
  else
    if [[ "${BLAB_IGNORE_SUPABASE_HEALTH_CHECKS:-0}" == '1' ]]; then
      supabase start --ignore-health-check
    else
      supabase start
    fi
    supabase db reset
  fi

  restore_postgres_version
  trap - EXIT
}

case "${1:-help}" in
  reset)
    reset_local
    print_accounts
    ;;
  accounts)
    print_accounts
    ;;
  android)
    android_device="${2:-emulator-5554}"
    ensure_android_device "$android_device"
    run_app "$android_device"
    ;;
  web)
    run_app chrome "${2:-}"
    ;;
  invite)
    print_web_invite "${2:-}"
    ;;
  functions)
    serve_functions
    ;;
  integration)
    run_integration
    ;;
  translation-limit)
    set_translation_limit "${2:-set}" "${3:-alice}"
    ;;
  history)
    seed_history "${2:-120}"
    ;;
  *)
    printf '%s\n' \
      'Usage:' \
      '  scripts/local_test.sh reset' \
      '  scripts/local_test.sh accounts' \
      '  scripts/local_test.sh android [device-id]' \
      '  scripts/local_test.sh web [copied-invite-url-or-token]' \
      '  scripts/local_test.sh invite <copied-url-or-token>' \
      '  scripts/local_test.sh functions' \
      '  scripts/local_test.sh integration' \
      '  scripts/local_test.sh translation-limit [set|clear] [alice|bob|carol]' \
      '  scripts/local_test.sh history [message-count]'
    ;;
esac
