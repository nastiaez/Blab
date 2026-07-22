#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
  printf 'CI Android release setup failed: %s\n' "$1" >&2
  exit 2
}

[[ "${CI:-}" == 'true' ]] || fail 'CI=true is required.'

properties_file='android/key.properties'
firebase_file='android/app/google-services.json'
firebase_fixture='config/ci/google-services.json'

[[ ! -e "$properties_file" ]] || fail "Refusing to overwrite $properties_file."
[[ ! -e "$firebase_file" ]] || fail "Refusing to overwrite $firebase_file."
[[ -f "$firebase_fixture" ]] || fail "Missing $firebase_fixture."

temporary_signing_dir="$(mktemp -d)"
cleanup() {
  rm -f "$properties_file" "$firebase_file"
  rm -rf "$temporary_signing_dir"
}
trap cleanup EXIT

cp "$firebase_fixture" "$firebase_file"
BLAB_SIGNING_DIR="$temporary_signing_dir" scripts/setup_android_signing.sh

flutter build appbundle --release \
  --dart-define=BLAB_ENV=local \
  --dart-define=SUPABASE_PROJECT_REF=local \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_ci_only_00000000000000000000000000000000 \
  --dart-define=SENTRY_ENV=local

[[ -s build/app/outputs/bundle/release/app-release.aab ]] || \
  fail 'Flutter did not produce a release AAB.'
