#!/usr/bin/env bash
# Ops: verify MongoDB text + prefix indexes and adminSearchBlob samples (Parse Cloud).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -f "$SCRIPT_DIR/.env.server" ] && source "$SCRIPT_DIR/.env.server"

PARSE_HOST="${FIN1_PARSE_CLOUD_SSH_HOST:-${FIN1_SERVER_IP:-192.168.178.20}}"
PARSE_URL="${PARSE_URL:-https://${PARSE_HOST}/parse}"
APP_ID="${PARSE_SERVER_APPLICATION_ID:-fin1-app-id}"

load_env_key() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  grep -E "^${key}=" "$file" | head -1 | cut -d= -f2- | tr -d '"' | tr -d "'"
}

if [ -z "${PARSE_SERVER_MASTER_KEY:-}" ]; then
  PARSE_SERVER_MASTER_KEY="$(load_env_key "${FIN1_SERVER_ENV:-$HOME/fin1-server/backend/.env}" PARSE_SERVER_MASTER_KEY || true)"
fi
if [ -z "${PARSE_SERVER_MASTER_KEY:-}" ]; then
  PARSE_SERVER_MASTER_KEY="$(ssh "${FIN1_SERVER_USER:-io}@${PARSE_HOST}" \
    "grep -E '^PARSE_SERVER_MASTER_KEY=' ~/fin1-server/backend/.env | head -1 | cut -d= -f2- | tr -d '\"' | tr -d \"'\"")"
fi

echo "=== getAdminListSearchHealth ==="
echo "  PARSE_URL=$PARSE_URL"
RESP="$(curl -sk --connect-timeout 30 -X POST "${PARSE_URL}/functions/getAdminListSearchHealth" \
  -H "X-Parse-Application-Id: ${APP_ID}" \
  -H "X-Parse-Master-Key: ${PARSE_SERVER_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d "{}")"

echo "$RESP" | python3 -m json.tool 2>/dev/null || echo "$RESP"

if echo "$RESP" | python3 -c "import json,sys; r=json.load(sys.stdin); exit(0 if r.get('result',r).get('healthy') else 1)" 2>/dev/null; then
  echo ""
  echo "OK: admin list search indexes healthy."
  exit 0
fi

echo ""
echo "Repair: FIN1_PARSE_CLOUD_SSH_HOST=$PARSE_HOST ./scripts/deploy-parse-cloud-to-fin1-server.sh"
echo "       then ensureAdminListSearchIndexes (master) + ./scripts/backfill-trade-summary-flags.sh"
exit 1
