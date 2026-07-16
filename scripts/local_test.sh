#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

password='Blab-local-123!'
postgres_version_file='supabase/.temp/postgres-version'
local_postgres_version="${BLAB_LOCAL_POSTGRES_VERSION:-17.6.1.084}"
function_env_file="${BLAB_FUNCTION_ENV_FILE:-supabase/.env.local}"

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
  local url

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
    local launch_url='http://localhost:7357/'
    if [[ -n "$invite_input" ]]; then
      launch_url="http://localhost:7357/#/i/$(invite_token "$invite_input")"
    fi
    "$@" -d chrome --web-port 7357 \
      --web-launch-url="$launch_url" \
      --dart-define="SUPABASE_URL=$url" \
      --dart-define="SUPABASE_PUBLISHABLE_KEY=$(local_key)"
  else
    "$@" -d "$device" \
      --dart-define="SUPABASE_URL=$url" \
      --dart-define="SUPABASE_PUBLISHABLE_KEY=$(local_key)"
  fi
}

reset_local() {
  local original_postgres_version
  original_postgres_version="$(cat "$postgres_version_file")"

  restore_postgres_version() {
    printf '%s' "$original_postgres_version" > "$postgres_version_file"
  }
  trap restore_postgres_version EXIT

  # Recover when a direct reset left the pinned image's database container
  # unhealthy. Reset is intentionally destructive to local Blab data.
  supabase stop --no-backup

  # The currently CLI-pinned 17.6.1.127 image has a zero-byte entrypoint on
  # this development machine. Use the verified compatible PG 17.6 image for
  # local resets without changing the repository's tracked CLI metadata.
  printf '%s' "$local_postgres_version" > "$postgres_version_file"
  if [[ "${SUPABASE_DEBUG:-0}" == '1' ]]; then
    supabase start --debug
    supabase db reset --debug
  else
    supabase start
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
  *)
    printf '%s\n' \
      'Usage:' \
      '  scripts/local_test.sh reset' \
      '  scripts/local_test.sh accounts' \
      '  scripts/local_test.sh android [device-id]' \
      '  scripts/local_test.sh web [copied-invite-url-or-token]' \
      '  scripts/local_test.sh invite <copied-url-or-token>' \
      '  scripts/local_test.sh functions'
    ;;
esac
