#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 <cluster> <app>" >&2
  echo "Creates <cluster>/<app> with Authelia OIDC client credentials." >&2
}

if [[ $# -ne 2 ]]; then
  usage
  exit 2
fi

cluster="$1"
app="$2"

if [[ ! "$cluster" =~ ^[a-zA-Z0-9._-]+$ || ! "$app" =~ ^[a-zA-Z0-9._-]+$ ]]; then
  echo "Error: cluster and app must contain only letters, numbers, '.', '_' or '-'" >&2
  exit 2
fi

command -v kubectl >/dev/null || {
  echo "Error: kubectl is required." >&2
  exit 1
}
command -v akeyless >/dev/null || {
  echo "Error: akeyless is required." >&2
  exit 1
}
command -v jq >/dev/null || {
  echo "Error: jq is required." >&2
  exit 1
}

secret_name="${cluster}/${app}"
if akeyless describe-item --name "$secret_name" >/dev/null 2>&1; then
  echo "Error: Akeyless secret '$secret_name' already exists." >&2
  exit 1
fi

running_pods=$(kubectl -n security get pods \
  -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.metadata.name}{"\n"}{end}')
authelia_pod=""
while IFS= read -r pod; do
  if [[ "$pod" == authelia-* ]]; then
    authelia_pod="$pod"
    break
  fi
done <<< "$running_pods"

if [[ -z "$authelia_pod" ]]; then
  echo "Error: No running Authelia pod found in the security namespace." >&2
  exit 1
fi

client_id_output=$(kubectl -n security exec "$authelia_pod" -- \
  authelia crypto rand --length 72 --charset rfc3986)
client_id=$(printf '%s\n' "$client_id_output" |
  sed -n 's/^Random Value:[[:space:]]*//p')

hash_output=$(kubectl -n security exec "$authelia_pod" -- \
  authelia crypto hash generate pbkdf2 --variant sha512 --random \
  --random.length 72 --random.charset rfc3986)
client_secret=$(printf '%s\n' "$hash_output" |
  sed -n 's/^Random Password:[[:space:]]*//p')

if [[ -z "$client_id" || -z "$client_secret" ]]; then
  echo "Error: Authelia did not return both OIDC credentials." >&2
  exit 1
fi

secret_value=$(jq -n \
  --arg client_id "$client_id" \
  --arg client_secret "$client_secret" \
  '{"client-id": $client_id, "client-secret": $client_secret}')

if ! akeyless create-secret \
  --name "$secret_name" \
  --value "$secret_value" \
  --type "generic" \
  --format "json" >/dev/null 2>&1; then
  echo "Error: Akeyless could not create the secret at '$secret_name'." >&2
  exit 1
fi

printf 'Created OIDC credentials at Akeyless path %s\n' "$secret_name"
