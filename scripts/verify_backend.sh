#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

environment="${1:-}"
case "$environment" in
  staging | production) ;;
  *)
    printf 'Usage: scripts/verify_backend.sh <staging|production>\n' >&2
    exit 2
    ;;
esac

command -v jq >/dev/null || {
  printf 'jq is required.\n' >&2
  exit 2
}

manifest="config/deployments/$environment.json"
project_ref="$(jq -er '.project_ref' "$manifest")"
expected_region="$(jq -er '.region' "$manifest")"
previous_ref=''
if [[ -f supabase/.temp/project-ref ]]; then
  previous_ref="$(cat supabase/.temp/project-ref)"
fi

restore_link() {
  if [[ -n "$previous_ref" && "$previous_ref" != "$project_ref" ]]; then
    supabase link --project-ref "$previous_ref" >/dev/null 2>&1 || true
  fi
}
trap restore_link EXIT

supabase link --project-ref "$project_ref" >/dev/null

projects_json="$(supabase projects list --agent yes)"
actual_region="$(
  printf '%s' "$projects_json" |
    jq -er --arg ref "$project_ref" '.projects[] | select(.ref == $ref) | .region'
)"
[[ "$actual_region" == "$expected_region" ]] || {
  printf 'Region drift: expected %s, found %s.\n' "$expected_region" "$actual_region" >&2
  exit 1
}

migrations_json="$(supabase migration list --linked --agent yes)"
local_migrations="$(
  find supabase/migrations -maxdepth 1 -type f -name '*.sql' -print |
    sed -E 's#^.*/([0-9]+)_.*#\1#' |
    sort -u
)"
remote_migrations="$(
  printf '%s' "$migrations_json" |
    jq -r '.migrations[] | select(.remote != null) | .remote' |
    sort -u
)"
[[ "$local_migrations" == "$remote_migrations" ]] || {
  printf 'Migration drift detected for %s.\n' "$environment" >&2
  diff -u <(printf '%s\n' "$local_migrations") <(printf '%s\n' "$remote_migrations") || true
  exit 1
}

functions_json="$(
  supabase functions list --project-ref "$project_ref" --agent yes
)"
while IFS=$'\t' read -r function_name verify_jwt; do
  actual="$(
    printf '%s' "$functions_json" |
      jq -er --arg name "$function_name" '
        .functions[] | select(.slug == $name and .status == "ACTIVE") |
        (.verify_jwt | tostring)
      '
  )" || {
    printf 'Missing active function: %s.\n' "$function_name" >&2
    exit 1
  }
  [[ "$actual" == "$verify_jwt" ]] || {
    printf 'JWT policy drift for %s.\n' "$function_name" >&2
    exit 1
  }
done < <(jq -r '.functions | to_entries[] | [.key, (.value | tostring)] | @tsv' "$manifest")

secrets_json="$(
  supabase secrets list --project-ref "$project_ref" --agent yes
)"
while IFS= read -r secret_name; do
  printf '%s' "$secrets_json" |
    jq -e --arg name "$secret_name" '.secrets[] | select(.name == $name)' \
      >/dev/null || {
        printf 'Missing required Edge Function secret: %s.\n' "$secret_name" >&2
        exit 1
      }
done < <(jq -r '.required_secrets[]' "$manifest")

printf '%s backend verified: region, migrations, functions, JWT policy, and secret names match.\n' "$environment"
