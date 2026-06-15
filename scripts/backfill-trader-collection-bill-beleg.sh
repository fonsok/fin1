#!/usr/bin/env bash
# Backfill trader collection bill SSOT (accountingSummaryText + metadata)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -f "$SCRIPT_DIR/.env.server" ] && source "$SCRIPT_DIR/.env.server"

PARSE_HOST="${FIN1_PARSE_CLOUD_SSH_HOST:-${FIN1_SERVER_IP:-192.168.178.20}}"
PARSE_URL="${PARSE_URL:-https://${PARSE_HOST}/parse}"
APP_ID="${PARSE_SERVER_APPLICATION_ID:-fin1-app-id}"
LIMIT="${BACKFILL_LIMIT:-50}"
DRY_RUN="${DRY_RUN:-false}"
FORCE="${FORCE:-false}"
DOCUMENT_NUMBER="${DOCUMENT_NUMBER:-}"
TRADE_ID="${TRADE_ID:-}"

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

build_payload() {
  local skip="$1"
  python3 - "$DRY_RUN" "$FORCE" "$LIMIT" "$skip" "$DOCUMENT_NUMBER" "$TRADE_ID" <<'PY'
import json, sys
dry_run, force, limit, skip, doc_num, trade_id = sys.argv[1:7]
payload = {
    "dryRun": dry_run.lower() not in ("false", "0", "no"),
    "force": force.lower() in ("true", "1", "yes"),
    "limit": int(limit),
    "skip": int(skip),
}
if doc_num:
    payload["documentNumber"] = doc_num
if trade_id:
    payload["tradeId"] = trade_id
print(json.dumps(payload))
PY
}

echo "=== backfillTraderCollectionBillBeleg ==="
echo "  PARSE_URL=$PARSE_URL"
echo "  dryRun=$DRY_RUN force=$FORCE limit=$LIMIT"
[ -n "$DOCUMENT_NUMBER" ] && echo "  documentNumber=$DOCUMENT_NUMBER"
[ -n "$TRADE_ID" ] && echo "  tradeId=$TRADE_ID"
echo ""

SKIP=0
TOTAL_EXAMINED=0
TOTAL_UPDATED=0

while true; do
  PAYLOAD="$(build_payload "$SKIP")"
  RESP="$(curl -sk --connect-timeout 120 -X POST "${PARSE_URL}/functions/backfillTraderCollectionBillBeleg" \
    -H "X-Parse-Application-Id: ${APP_ID}" \
    -H "X-Parse-Master-Key: ${PARSE_SERVER_MASTER_KEY}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")"

  if echo "$RESP" | grep -q '"error"'; then
    echo "$RESP" | python3 -m json.tool 2>/dev/null || echo "$RESP"
    exit 1
  fi

  echo "$RESP" | python3 -m json.tool

  EXAMINED="$(echo "$RESP" | python3 -c 'import json,sys; r=json.load(sys.stdin); print(r.get("result",r).get("examined",0))')"
  UPDATED="$(echo "$RESP" | python3 -c 'import json,sys; r=json.load(sys.stdin); print(r.get("result",r).get("updated",0))')"
  HAS_MORE="$(echo "$RESP" | python3 -c 'import json,sys; r=json.load(sys.stdin); print("true" if r.get("result",r).get("hasMore") else "false")')"
  NEXT_SKIP="$(echo "$RESP" | python3 -c 'import json,sys; r=json.load(sys.stdin); print(r.get("result",r).get("skip",0)+r.get("result",r).get("limit",50))')"

  TOTAL_EXAMINED=$((TOTAL_EXAMINED + EXAMINED))
  TOTAL_UPDATED=$((TOTAL_UPDATED + UPDATED))

  if [ "$HAS_MORE" != "true" ] || [ "$EXAMINED" -eq 0 ]; then
    break
  fi
  SKIP="$NEXT_SKIP"
done

echo ""
echo "Done. examined=$TOTAL_EXAMINED updated=$TOTAL_UPDATED"
