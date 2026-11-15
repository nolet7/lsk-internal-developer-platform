#!/usr/bin/env bash
set -euo pipefail
# Run from trusted private network after infrastructure, schema and OIDC setup.
# Never print the JWT, payloads or other sensitive credentials.
: "${API_BASE_URL:?Set API_BASE_URL to approved regional HTTPS endpoint}"
: "${APPLICATION_JWT:?Set APPLICATION_JWT with required read scope}"
if [[ "$API_BASE_URL" != https://* ]]; then echo "HTTPS required" >&2; exit 1; fi
endpoint="/v1/catalog"
headers=()
if [[ -n "${SERVERLESS_ID_TOKEN:-}" ]]; then
  # Google Cloud Run IAM token is separate from the application's OIDC JWT.
  headers+=(-H "X-Serverless-Authorization: Bearer $SERVERLESS_ID_TOKEN")
fi
base="${API_BASE_URL%/}"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
check() {
  local label="$1" path="$2" expected="$3"
  shift 3
  local status
  status=$(curl --silent --show-error --max-time 20 -o "$tmp" -w '%{http_code}' "${headers[@]}" "$@" "$base$path")
  if [[ "$status" != "$expected" ]]; then
    echo "$label returned HTTP $status; expected $expected" >&2
    exit 1
  fi
  echo "$label: HTTP $status"
}
check "health" /healthz 200
check "database connection" /readyz 200
check "unauthorized business operation" "$endpoint" 401
check "authenticated business operation and schema" "$endpoint" 200 -H "Authorization: Bearer $APPLICATION_JWT"
echo "Regional smoke tests passed; run tenant isolation, load, backup and disaster recovery checks separately."
