#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
properties_file="$repo_root/android/key.properties"
signing_dir="${BLAB_SIGNING_DIR:-$HOME/.config/blab/signing}"
keystore_file="$signing_dir/blab-upload.jks"
alias_name='upload'

if [[ -e "$properties_file" || -e "$keystore_file" ]]; then
  printf '%s\n' \
    'Refusing to overwrite existing Android signing material.' \
    "Properties: $properties_file" \
    "Keystore:   $keystore_file" >&2
  exit 2
fi

for command_name in keytool openssl; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$command_name" >&2
    exit 2
  fi
done

umask 077
mkdir -p "$signing_dir"
password="$(openssl rand -hex 32)"
temporary_properties="$properties_file.tmp.$$"

cleanup() {
  rm -f "$temporary_properties"
  unset password
}
trap cleanup EXIT

keytool -genkeypair \
  -keystore "$keystore_file" \
  -storetype PKCS12 \
  -storepass "$password" \
  -keypass "$password" \
  -alias "$alias_name" \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -dname 'CN=Blab Upload, OU=Mobile, O=Blab, L=Berlin, ST=Berlin, C=DE' \
  >/dev/null

printf '%s\n' \
  "storeFile=$keystore_file" \
  "storePassword=$password" \
  "keyAlias=$alias_name" \
  "keyPassword=$password" \
  >"$temporary_properties"
chmod 600 "$temporary_properties"
mv "$temporary_properties" "$properties_file"

fingerprint="$(
  keytool -J-Duser.language=en -list -v \
    -keystore "$keystore_file" \
    -storepass "$password" \
    -alias "$alias_name" |
    awk -F'SHA256: ' '/SHA256: / {print $2; exit}'
)"

printf '%s\n' \
  'Created the Blab Android upload key.' \
  "Keystore:   $keystore_file" \
  "Properties: $properties_file" \
  "SHA-256:    $fingerprint" \
  '' \
  'Back up both files in an owner-controlled encrypted location.' \
  'The generated password is stored only in the gitignored properties file.'
