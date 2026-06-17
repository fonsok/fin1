#!/usr/bin/env bash
# ADR-018 P3c: inspect recent AccountStatement rows for cent-aligned monetary fields.
#
# Usage:
#   ./scripts/check-account-statement-cent-alignment.sh
#   LIMIT_ROWS=1000 USER_ID=qyqqjDvDnM ./scripts/check-account-statement-cent-alignment.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -f "$SCRIPT_DIR/.env.server" ] && source "$SCRIPT_DIR/.env.server"

PARSE_HOST="${FIN1_PARSE_CLOUD_SSH_HOST:-${FIN1_SERVER_IP:-192.168.178.20}}"
PARSE_URL="${PARSE_URL:-https://${PARSE_HOST}/parse}"
APP_ID="${PARSE_SERVER_APPLICATION_ID:-fin1-app-id}"
LIMIT_ROWS="${LIMIT_ROWS:-500}"
PREVIEW_LIMIT="${PREVIEW_LIMIT:-25}"
USER_ID="${USER_ID:-}"

load_env_key() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  grep -E "^${key}=" "$file" | head -1 | cut -d= -f2- | tr -d '"' | tr -d "'"
}

ENV_FILE="${FIN1_SERVER_ENV:-$HOME/fin1-server/backend/.env}"
if [ -z "${PARSE_SERVER_MASTER_KEY:-}" ]; then
  PARSE_SERVER_MASTER_KEY="$(load_env_key "$ENV_FILE" PARSE_SERVER_MASTER_KEY || true)"
fi
if [ -z "${PARSE_SERVER_MASTER_KEY:-}" ]; then
  echo "Loading master key from ${FIN1_SERVER_USER:-io}@${PARSE_HOST} …"
  PARSE_SERVER_MASTER_KEY="$(ssh "${FIN1_SERVER_USER:-io}@${PARSE_HOST}" \
    "grep -E '^PARSE_SERVER_MASTER_KEY=' ~/fin1-server/backend/.env | head -1 | cut -d= -f2- | tr -d '\"' | tr -d \"'\"")"
fi
if [ -z "${PARSE_SERVER_MASTER_KEY:-}" ]; then
  echo "Error: PARSE_SERVER_MASTER_KEY not available."
  exit 1
fi

PAYLOAD="$(python3 - "$LIMIT_ROWS" "$PREVIEW_LIMIT" "$USER_ID" <<'PY'
import json, sys
limit_rows, preview_limit, user_id = sys.argv[1:4]
payload = {
    "limitRows": int(limit_rows),
    "previewLimit": int(preview_limit),
}
if user_id.strip():
    payload["userId"] = user_id.strip()
print(json.dumps(payload))
PY
)"

echo "=== checkAccountStatementCentAlignment ==="
echo "  PARSE_URL=$PARSE_URL"
echo "  limitRows=$LIMIT_ROWS previewLimit=$PREVIEW_LIMIT"
[ -n "$USER_ID" ] && echo "  userId=$USER_ID"
echo ""

RESP="$(curl -sk --connect-timeout 180 -X POST "${PARSE_URL}/functions/checkAccountStatementCentAlignment" \
  -H "X-Parse-Application-Id: ${APP_ID}" \
  -H "X-Parse-Master-Key: ${PARSE_SERVER_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")"

if echo "$RESP" | grep -q '"error"'; then
  echo "$RESP" | python3 -m json.tool 2>/dev/null || echo "$RESP"
  exit 1
fi

echo "$RESP" | python3 -m json.tool

HEALTHY="$(echo "$RESP" | python3 -c 'import json,sys; r=json.load(sys.stdin); print("true" if r.get("result",r).get("healthy") else "false")')"
VIOLATIONS="$(echo "$RESP" | python3 -c 'import json,sys; r=json.load(sys.stdin); print(r.get("result",r).get("violationRows",0))')"

echo ""
if [ "$HEALTHY" = "true" ]; then
  echo "OK: all sampled AccountStatement monetary fields are cent-aligned."
  exit 0
fi

echo "Non-cent-aligned writes detected: violationRows=$VIOLATIONS"
exit 2
