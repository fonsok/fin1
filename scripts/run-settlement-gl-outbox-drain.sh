#!/usr/bin/env bash
# Drain pending SettlementOutbox rows (ADR-017 async GL posting).
#
# Usage:
#   ./scripts/run-settlement-gl-outbox-drain.sh
#   SETTLEMENT_GL_OUTBOX_LIMIT=100 ./scripts/run-settlement-gl-outbox-drain.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -f "$SCRIPT_DIR/.env.server" ] && source "$SCRIPT_DIR/.env.server"

LIMIT="${SETTLEMENT_GL_OUTBOX_LIMIT:-50}"
PARSE_HOST="${FIN1_PARSE_CLOUD_SSH_HOST:-${FIN1_SERVER_IP:-192.168.178.20}}"
PARSE_URL="${PARSE_URL:-https://${PARSE_HOST}/parse}"
APP_ID="${PARSE_SERVER_APPLICATION_ID:-fin1-app-id}"

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

echo "=== runSettlementGLOutbox (limit=$LIMIT) ==="
echo "  PARSE_URL=$PARSE_URL"
echo ""

RESPONSE="$(curl -sk --connect-timeout 120 -X POST "${PARSE_URL}/functions/runSettlementGLOutbox" \
  -H "X-Parse-Application-Id: ${APP_ID}" \
  -H "X-Parse-Master-Key: ${PARSE_SERVER_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "import json; print(json.dumps({'limit': int('${LIMIT}')}))")")"

if echo "$RESPONSE" | grep -q '"error"'; then
  echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
  exit 1
fi

python3 -c "
import json, sys
raw = json.loads(sys.argv[1])
r = raw.get('result') or {}
processed = int(r.get('processed') or 0)
print(f'processed={processed}')
print(f'ran_at={r.get(\"ranAt\", \"\")}')
if processed == 0:
    print('OK: no pending SettlementOutbox rows')
else:
    print('OK: drained', processed, 'row(s)')
" "$RESPONSE"
