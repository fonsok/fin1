#!/usr/bin/env bash
# Post-P3c-1 settlement health: AccountStatement chain, GL reconciliation, trader beleg drift.
# Run after at least one trade settlement since P3c-1 deploy (see ADR-018).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -f "$SCRIPT_DIR/.env.server" ] && source "$SCRIPT_DIR/.env.server"

PARSE_HOST="${FIN1_PARSE_CLOUD_SSH_HOST:-${FIN1_SERVER_IP:-192.168.178.20}}"
PARSE_URL="${PARSE_URL:-https://${PARSE_HOST}/parse}"
APP_ID="${PARSE_SERVER_APPLICATION_ID:-fin1-app-id}"
TRADER_EMAIL="${TRADER_EMAIL:-trader1@test.com}"
INVESTOR_EMAIL="${INVESTOR_EMAIL:-investor5@test.com}"
BELEG_DRIFT_LIMIT="${BELEG_DRIFT_LIMIT:-50}"
GL_RECON_LIMIT="${GL_RECON_LIMIT:-50}"
TRADE_ID="${TRADE_ID:-}"
USER_IDS="${USER_IDS:-}"
RUN_IOBOX_MONITORS="${RUN_IOBOX_MONITORS:-false}"

FAILURES=0

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

parse_function() {
  local fn="$1"
  local body="$2"
  curl -sk --connect-timeout 120 -X POST "${PARSE_URL}/functions/${fn}" \
    -H "X-Parse-Application-Id: ${APP_ID}" \
    -H "X-Parse-Master-Key: ${PARSE_SERVER_MASTER_KEY}" \
    -H "Content-Type: application/json" \
    -d "$body"
}

resolve_user_id() {
  local email="$1"
  local qs
  qs="$(python3 - "$email" <<'PY'
import json, sys, urllib.parse
email = sys.argv[1]
print(urllib.parse.urlencode({
    'where': json.dumps({'email': email}),
    'keys': 'objectId,email',
    'limit': '1',
}))
PY
)"
  local resp
  resp="$(curl -sk --connect-timeout 30 \
    "${PARSE_URL}/users?${qs}" \
    -H "X-Parse-Application-Id: ${APP_ID}" \
    -H "X-Parse-Master-Key: ${PARSE_SERVER_MASTER_KEY}")"
  echo "$resp" | python3 -c "
import json,sys
r=json.load(sys.stdin).get('results') or []
print(r[0].get('objectId','') if r else '')
"
}

mark_failure() {
  FAILURES=$((FAILURES + 1))
  echo "  FAIL: $1"
}

echo "=== post-p3c-settlement-health-check ==="
echo "  PARSE_URL=$PARSE_URL"
echo "  trader=$TRADER_EMAIL investor=$INVESTOR_EMAIL"
[ -n "$TRADE_ID" ] && echo "  tradeId=$TRADE_ID (beleg drift scope)"
echo ""

if [ -z "$USER_IDS" ]; then
  TRADER_ID="$(resolve_user_id "$TRADER_EMAIL")"
  INVESTOR_ID="$(resolve_user_id "$INVESTOR_EMAIL")"
  if [ -z "$TRADER_ID" ]; then
    echo "Error: could not resolve userId for $TRADER_EMAIL"
    exit 1
  fi
  if [ -z "$INVESTOR_ID" ]; then
    echo "Error: could not resolve userId for $INVESTOR_EMAIL"
    exit 1
  fi
  USER_IDS="$TRADER_ID,$INVESTOR_ID"
fi

echo "▸ verifyAccountStatementChain"
IFS=',' read -r -a UID_LIST <<< "$USER_IDS"
for uid in "${UID_LIST[@]}"; do
  uid="$(echo "$uid" | tr -d ' ')"
  [ -z "$uid" ] && continue
  echo "  userId=$uid"
  RESP="$(parse_function verifyAccountStatementChain "{\"userId\":\"${uid}\"}")"
  if echo "$RESP" | grep -q '"error"'; then
    mark_failure "verifyAccountStatementChain $uid — Parse error"
    echo "$RESP" | python3 -m json.tool 2>/dev/null || echo "$RESP"
    continue
  fi
  echo "$RESP" | python3 -c "
import json,sys
r=json.load(sys.stdin).get('result',{})
ok=bool(r.get('validChain')) and r.get('chainBreakCount',1)==0 and r.get('arithmeticBreakCount',1)==0
print('  ', 'OK' if ok else 'FAIL',
      '| entries=', r.get('entryCount'),
      '| chainBreaks=', r.get('chainBreakCount'),
      '| arithBreaks=', r.get('arithmeticBreakCount'),
      '| sumMatches=', r.get('sumMatchesLastClosing'))
if not ok:
    if r.get('firstChainBreak'): print('    firstChainBreak:', r['firstChainBreak'])
    if r.get('firstArithmeticBreak'): print('    firstArithmeticBreak:', r['firstArithmeticBreak'])
    sys.exit(1)
" || mark_failure "chain verify $uid"
done

echo ""
echo "▸ getSettlementGLReconciliationStatus"
GL_RESP="$(parse_function getSettlementGLReconciliationStatus "{\"limit\":${GL_RECON_LIMIT}}")"
if echo "$GL_RESP" | grep -q '"error"'; then
  mark_failure "getSettlementGLReconciliationStatus — Parse error"
  echo "$GL_RESP" | python3 -m json.tool 2>/dev/null || echo "$GL_RESP"
else
  echo "$GL_RESP" | python3 -c "
import json,sys
r=json.load(sys.stdin).get('result',{})
o=str(r.get('overall',''))
v=int(r.get('violationCount',-1))
ok=o in ('healthy','unknown') and v==0
print('  ', 'OK' if ok else 'FAIL', '| overall=', o, '| violations=', v, '| checkedTrades=', r.get('checkedTrades'))
if r.get('samples'):
    print('    samples:', json.dumps(r['samples'][:3], indent=2))
if not ok: sys.exit(1)
" || mark_failure "settlement GL reconciliation"
fi

echo ""
echo "▸ checkTraderCollectionBillBelegDrift"
BELEG_PAYLOAD="$(python3 -c "
import json
p={'limit': int('${BELEG_DRIFT_LIMIT}'), 'includeInvoice': False}
tid='${TRADE_ID}'.strip()
if tid: p['tradeId']=tid
print(json.dumps(p))
")"
BELEG_RESP="$(parse_function checkTraderCollectionBillBelegDrift "$BELEG_PAYLOAD")"
if echo "$BELEG_RESP" | grep -q '"error"'; then
  mark_failure "checkTraderCollectionBillBelegDrift — Parse error"
  echo "$BELEG_RESP" | python3 -m json.tool 2>/dev/null || echo "$BELEG_RESP"
else
  echo "$BELEG_RESP" | python3 -m json.tool
  echo "$BELEG_RESP" | python3 -c "
import json,sys
r=json.load(sys.stdin).get('result',{})
ok=r.get('overall')=='healthy' and r.get('drifted',1)==0 and r.get('needsBackfill',1)==0
print('  ', 'OK' if ok else 'FAIL', '| overall=', r.get('overall'), '| drifted=', r.get('drifted'), '| needsBackfill=', r.get('needsBackfill'))
if not ok: sys.exit(1)
" || mark_failure "trader beleg drift"
fi

if [ "$RUN_IOBOX_MONITORS" = "true" ]; then
  echo ""
  echo "▸ iobox monitors (ssh ${FIN1_SERVER_USER:-io}@${PARSE_HOST})"
  ssh "${FIN1_SERVER_USER:-io}@${PARSE_HOST}" bash -s <<'REMOTE'
set -euo pipefail
cd ~/fin1-server/scripts
./run-finance-integrity-monitor.sh
./run-settlement-gl-reconciliation-monitor.sh
echo "  OK iobox monitors (exit 0)"
REMOTE
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "=== post-p3c-settlement-health-check: OK (all checks passed) ==="
  exit 0
fi

echo "=== post-p3c-settlement-health-check: FAILED ($FAILURES check(s)) ==="
exit 1
