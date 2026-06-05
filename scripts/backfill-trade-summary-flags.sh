#!/usr/bin/env bash
# Paginated backfill: Trade.hasPoolParticipation + traderPartialSellEventCount
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -f "$SCRIPT_DIR/.env.server" ] && source "$SCRIPT_DIR/.env.server"

PARSE_HOST="${FIN1_PARSE_CLOUD_SSH_HOST:-${FIN1_SERVER_IP:-192.168.178.20}}"
PARSE_URL="${PARSE_URL:-https://${PARSE_HOST}/parse}"
APP_ID="${PARSE_SERVER_APPLICATION_ID:-fin1-app-id}"
LIMIT="${BACKFILL_LIMIT:-100}"

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
  echo "Loading master key from ${REMOTE_USER:-io}@${PARSE_HOST} …"
  PARSE_SERVER_MASTER_KEY="$(ssh "${FIN1_SERVER_USER:-io}@${PARSE_HOST}" \
    "grep -E '^PARSE_SERVER_MASTER_KEY=' ~/fin1-server/backend/.env | head -1 | cut -d= -f2- | tr -d '\"' | tr -d \"'\"")"
fi
if [ -z "${PARSE_SERVER_MASTER_KEY:-}" ]; then
  echo "Error: PARSE_SERVER_MASTER_KEY not available."
  exit 1
fi

echo "=== backfillTradeSummaryFlags — trades (limit=$LIMIT) ==="
echo "  PARSE_URL=$PARSE_URL"
echo ""

SKIP=0
TOTAL_PROCESSED=0
TOTAL_UPDATED=0

while true; do
  RESP="$(curl -sk --connect-timeout 120 -X POST "${PARSE_URL}/functions/backfillTradeSummaryFlags" \
    -H "X-Parse-Application-Id: ${APP_ID}" \
    -H "X-Parse-Master-Key: ${PARSE_SERVER_MASTER_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"limit\":${LIMIT},\"skip\":${SKIP}}")"

  if echo "$RESP" | grep -q '"error"'; then
    echo "$RESP" | python3 -m json.tool 2>/dev/null || echo "$RESP"
    exit 1
  fi

  PROCESSED="$(echo "$RESP" | python3 -c 'import json,sys; r=json.load(sys.stdin); print(r.get("result",r).get("processed",0))')"
  UPDATED="$(echo "$RESP" | python3 -c 'import json,sys; r=json.load(sys.stdin); print(r.get("result",r).get("updated",0))')"
  HAS_MORE="$(echo "$RESP" | python3 -c 'import json,sys; r=json.load(sys.stdin); print("true" if r.get("result",r).get("hasMore") else "false")')"
  NEXT_SKIP="$(echo "$RESP" | python3 -c 'import json,sys; r=json.load(sys.stdin); print(r.get("result",r).get("nextSkip",0))')"

  TOTAL_PROCESSED=$((TOTAL_PROCESSED + PROCESSED))
  TOTAL_UPDATED=$((TOTAL_UPDATED + UPDATED))
  echo "  skip=$SKIP processed=$PROCESSED updated=$UPDATED hasMore=$HAS_MORE"

  if [ "$HAS_MORE" != "true" ] || [ "$PROCESSED" -eq 0 ]; then
    break
  fi
  SKIP="$NEXT_SKIP"
done

echo ""
echo "=== backfillTradeSummaryFlags — investments ==="
SKIP=0
while true; do
  RESP="$(curl -sk --connect-timeout 120 -X POST "${PARSE_URL}/functions/backfillTradeSummaryFlags" \
    -H "X-Parse-Application-Id: ${APP_ID}" \
    -H "X-Parse-Master-Key: ${PARSE_SERVER_MASTER_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"limit\":${LIMIT},\"skip\":${SKIP},\"entity\":\"investment\"}")"
  if echo "$RESP" | grep -q '"error"'; then
    echo "$RESP" | python3 -m json.tool 2>/dev/null || echo "$RESP"
    exit 1
  fi
  PROCESSED="$(echo "$RESP" | python3 -c 'import json,sys; r=json.load(sys.stdin); print(r.get("result",r).get("processed",0))')"
  UPDATED="$(echo "$RESP" | python3 -c 'import json,sys; r=json.load(sys.stdin); print(r.get("result",r).get("updated",0))')"
  HAS_MORE="$(echo "$RESP" | python3 -c 'import json,sys; r=json.load(sys.stdin); print("true" if r.get("result",r).get("hasMore") else "false")')"
  NEXT_SKIP="$(echo "$RESP" | python3 -c 'import json,sys; r=json.load(sys.stdin); print(r.get("result",r).get("nextSkip",0))')"
  echo "  investments skip=$SKIP processed=$PROCESSED updated=$UPDATED hasMore=$HAS_MORE"
  if [ "$HAS_MORE" != "true" ] || [ "$PROCESSED" -eq 0 ]; then
    break
  fi
  SKIP="$NEXT_SKIP"
done

echo ""
echo "Done. trades: processed=$TOTAL_PROCESSED updated=$TOTAL_UPDATED"
