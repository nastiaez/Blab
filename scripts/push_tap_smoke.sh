#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

usage() {
  cat <<'USAGE'
Usage:
  scripts/push_tap_smoke.sh <staging|production> <device-id> <background|killed> <expected-chat-id>

Runs the Android push-tap smoke check against a connected emulator/device.
The app must be signed in as the notification recipient before the script
puts it into the requested state. Send a real message/invite push from another
account, tap the notification, and the script verifies logcat contains:
  - Push tap received: ... chatId=<expected-chat-id>
  - Push tap routing opened chatId=<expected-chat-id>

This proves "notification appeared" and "tap opened the correct chat" as two
separate facts. It requires real Firebase/Supabase push credentials for the
selected environment.
USAGE
}

environment="${1:-}"
device="${2:-}"
mode="${3:-}"
expected_chat_id="${4:-}"
package_name="blab.nastia.ez"
log_file="${TMPDIR:-/tmp}/blab-push-tap-${device:-device}-$(date +%Y%m%d%H%M%S).log"

case "$environment" in
  staging | production) ;;
  *) usage; exit 2 ;;
esac
[[ -n "$device" ]] || { usage; exit 2; }
case "$mode" in
  background | killed) ;;
  *) usage; exit 2 ;;
esac
if [[ ! "$expected_chat_id" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$ ]]; then
  printf 'Expected chat id must be a UUID.\n' >&2
  exit 2
fi

command -v adb >/dev/null || { printf 'adb is required.\n' >&2; exit 2; }
adb -s "$device" get-state >/dev/null

config_file="env/$environment.json"
firebase_file="env/firebase/$environment/google-services.json"
missing=0
for field in GOOGLE_WEB_CLIENT_ID FIREBASE_PROJECT_ID SENTRY_DSN; do
  value="$(jq -r --arg field "$field" '.[$field] // ""' "$config_file" 2>/dev/null || true)"
  lower_value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  if [[ -z "$value" || "$lower_value" == *replace_with* || "$lower_value" == *placeholder* ]]; then
    printf 'Push smoke blocked: %s is not configured in %s.\n' "$field" "$config_file" >&2
    missing=1
  fi
done
if [[ ! -f "$firebase_file" ]]; then
  printf 'Push smoke blocked: missing %s.\n' "$firebase_file" >&2
  missing=1
else
  firebase_project="$(jq -r '.project_info.project_id // ""' "$firebase_file")"
  firebase_api_key="$(jq -r '.client[0].api_key[0].current_key // ""' "$firebase_file")"
  config_project="$(jq -r '.FIREBASE_PROJECT_ID // ""' "$config_file")"
  if [[ -n "$config_project" && "$firebase_project" != "$config_project" ]]; then
    printf 'Push smoke blocked: %s project does not match FIREBASE_PROJECT_ID.\n' "$firebase_file" >&2
    missing=1
  fi
  if [[ "$firebase_project" == 'blab-ci-only' || "$firebase_api_key" == *'CI_ONLY_NOT_A_REAL_FIREBASE_API_KEY'* ]]; then
    printf 'Push smoke blocked: CI-only Firebase configuration cannot receive real FCM pushes.\n' >&2
    missing=1
  fi
fi
if [[ "$missing" == "1" ]]; then
  printf 'Real FCM smoke needs matching Firebase Android config and hosted app env values.\n' >&2
  exit 2
fi

scripts/blab_environment.sh validate "$environment"
flutter build apk --debug --dart-define-from-file="env/$environment.json"
adb -s "$device" install -r build/app/outputs/flutter-apk/app-debug.apk >/dev/null
adb -s "$device" logcat -c
adb -s "$device" shell monkey -p "$package_name" 1 >/dev/null

cat <<EOF
Blab is installed and launched on $device.
1. Confirm this app session is signed in as the notification recipient.
2. Press Enter here; I will put the app into '$mode' state.
3. Send a real push-triggering message/invite from another account.
4. When the notification appears, tap it.

Capturing logcat to: $log_file
EOF
read -r

case "$mode" in
  background)
    adb -s "$device" shell input keyevent HOME
    ;;
  killed)
    adb -s "$device" shell input keyevent HOME
    adb -s "$device" shell am kill "$package_name" || true
    ;;
esac

printf 'Waiting up to 180s for push tap route evidence...\n'
timeout 180 adb -s "$device" logcat -v time >"$log_file" &
log_pid=$!
cleanup() {
  kill "$log_pid" >/dev/null 2>&1 || true
}
trap cleanup EXIT

deadline=$((SECONDS + 180))
while (( SECONDS < deadline )); do
  if grep -F "Push tap received:" "$log_file" | grep -F "chatId=$expected_chat_id" >/dev/null &&
     grep -F "Push tap routing opened chatId=$expected_chat_id" "$log_file" >/dev/null; then
    printf 'Push tap route verified for chat %s\n' "$expected_chat_id"
    printf 'Log file: %s\n' "$log_file"
    exit 0
  fi
  sleep 2
done

printf 'Timed out waiting for push tap route evidence.\n' >&2
printf 'Expected chat: %s\n' "$expected_chat_id" >&2
printf 'Log file: %s\n' "$log_file" >&2
printf 'Recent notification/Firebase/Blab lines:\n' >&2
grep -Ei 'Push tap|FirebaseMessaging|notification|FCM|ActivityTaskManager|blab' "$log_file" | tail -80 >&2 || true
exit 1
