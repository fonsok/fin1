#!/usr/bin/env bash
set -euo pipefail

# Auth-based smoke test for auditCollectionBillReturnPercentage.
# Requires a real admin session token (not master key).
#
# Usage:
#   PARSE_SERVER_URL="https://host/parse" \
#   PARSE_APP_ID="..." \
#   PARSE_SESSION_TOKEN="r:..." \
#   ./scripts/smoke-audit-return-percentage-auth.sh

PARSE_SERVER_URL="${PARSE_SERVER_URL:-}"
PARSE_APP_ID="${PARSE_APP_ID:-}"
PARSE_SESSION_TOKEN="${PARSE_SESSION_TOKEN:-}"

if [[ -z "$PARSE_SERVER_URL" || -z "$PARSE_APP_ID" || -z "$PARSE_SESSION_TOKEN" ]]; then
  echo "Missing required env vars: PARSE_SERVER_URL, PARSE_APP_ID, PARSE_SESSION_TOKEN"
  exit 2
fi

BASE_URL="${PARSE_SERVER_URL%/}"
if [[ "$BASE_URL" != */parse ]]; then
  BASE_URL="${BASE_URL}/parse"
fi

RESPONSE="$(
  curl -sS -X POST "${BASE_URL}/functions/auditCollectionBillReturnPercentage" \
    -H "X-Parse-Application-Id: ${PARSE_APP_ID}" \
    -H "X-Parse-Session-Token: ${PARSE_SESSION_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"limit":3}'
)"

echo "$RESPONSE"

if [[ "$RESPONSE" == *"\"error\""* ]]; then
  echo "Smoke test failed."
  exit 1
fi

echo "Smoke test succeeded."
