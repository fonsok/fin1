#!/usr/bin/env bash
# End-to-end: Parse login as trader → executePairedBuy → getOpenTrades (trader leg trade)
# → idempotent replay verifies DB settlement.
#
# Env (optional):
#   PARSE_SERVER_URL       default https://192.168.178.20/parse
#   PARSE_APPLICATION_ID   default fin1-app-id
#   E2E_TRADER_USERNAME      default trader1@test.com (Parse username; Dev seeds use email-as-username)
#   E2E_TRADER_PASSWORD      default TestPassword123!
#
# Requirements: curl, python3
#
set -euo pipefail

PARSE_URL="${PARSE_SERVER_URL:-https://192.168.178.20/parse}"
APP_ID="${PARSE_APPLICATION_ID:-fin1-app-id}"
export PARSE_URL APP_ID
TRADER_USER="${E2E_TRADER_USERNAME:-trader1@test.com}"
TRADER_PASS="${E2E_TRADER_PASSWORD:-TestPassword123!}"
export TRADER_USER TRADER_PASS

INTENT_ID="e2e-paired-$(date +%s)-${RANDOM}-$$"
export INTENT_ID

echo "[e2e] Parse URL: ${PARSE_URL}"
echo "[e2e] Trader: ${TRADER_USER}"
echo "[e2e] clientOrderIntentId: ${INTENT_ID}"

LOGIN_JSON="$(curl -sk -X POST "${PARSE_URL}/login" \
  -H "X-Parse-Application-Id: ${APP_ID}" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c 'import json, os; print(json.dumps({"username": os.environ["TRADER_USER"], "password": os.environ["TRADER_PASS"]}))')")"

SESSION="$(python3 -c "
import json, sys
d = json.loads(sys.argv[1])
if d.get('code') or d.get('error'):
    sys.stderr.write('Login failed: ' + json.dumps(d) + chr(10))
    sys.exit(1)
tok = d.get('sessionToken')
if not tok:
    sys.stderr.write('Login failed: no sessionToken in ' + json.dumps(d) + chr(10))
    sys.exit(1)
print(tok)
" "${LOGIN_JSON}")"

echo "[e2e] Login OK"

PAYLOAD="$(python3 -c '
import json, os
print(json.dumps({
  "symbol": "E2E-PAIRED-WKN",
  "price": 100.0,
  "orderInstruction": "market",
  "clientOrderIntentId": os.environ["INTENT_ID"],
  "traderQuantity": 1,
  "mirrorPoolQuantity": 1,
  "description": "E2E paired buy script",
}))
')"

call_paired_buy() {
  curl -sk -X POST "${PARSE_URL}/functions/executePairedBuy" \
    -H "X-Parse-Application-Id: ${APP_ID}" \
    -H "X-Parse-Session-Token: ${SESSION}" \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}"
}

FIRST_FILE="$(mktemp)"
SECOND_FILE="$(mktemp)"
OPEN_TRADES_FILE="$(mktemp)"
trap 'rm -f "${FIRST_FILE}" "${SECOND_FILE}" "${OPEN_TRADES_FILE}"' EXIT

call_paired_buy >"${FIRST_FILE}"

PAIR_ID="$(python3 -c "
import json, sys
raw = json.load(open(sys.argv[1]))
if raw.get('code') or raw.get('error'):
    sys.stderr.write('First executePairedBuy failed: ' + json.dumps(raw) + chr(10))
    sys.exit(1)
if 'result' not in raw:
    sys.stderr.write('First call missing result: ' + json.dumps(raw) + chr(10))
    sys.exit(1)
r = raw['result']
pid = r.get('pairExecutionId')
if not pid:
    sys.stderr.write('Missing pairExecutionId: ' + json.dumps(raw) + chr(10))
    sys.exit(1)
print(pid)
" "${FIRST_FILE}")"

echo "[e2e] First executePairedBuy OK pairExecutionId=${PAIR_ID}"

curl -sk -X POST "${PARSE_URL}/functions/getOpenTrades" \
  -H "X-Parse-Application-Id: ${APP_ID}" \
  -H "X-Parse-Session-Token: ${SESSION}" \
  -H "Content-Type: application/json" \
  -d '{}' \
  >"${OPEN_TRADES_FILE}"

echo "[e2e] getOpenTrades OK (saved response for assertions)"

call_paired_buy >"${SECOND_FILE}"

python3 - "${FIRST_FILE}" "${SECOND_FILE}" "${PAIR_ID}" "${OPEN_TRADES_FILE}" <<'PY'
import json
import sys


def fail(msg):
    raise SystemExit(msg)


first = json.load(open(sys.argv[1]))
second = json.load(open(sys.argv[2]))
pair_id = sys.argv[3]
open_trades_raw = json.load(open(sys.argv[4]))

for label, raw in ('first', first), ('replay', second):
    if raw.get('code') or raw.get('error'):
        fail(f'{label}: Parse error envelope: {json.dumps(raw)}')

if 'result' not in second:
    fail('replay: missing result')

r2 = second['result']
if not r2.get('idempotentReplay'):
    fail('Expected idempotentReplay=true on second call: ' + json.dumps(r2))
if str(r2.get('status') or '') != 'COMMITTED':
    fail('Expected status COMMITTED on replay: ' + json.dumps(r2))

orders = r2.get('orders') or []
if len(orders) != 2:
    fail('Expected 2 order legs: ' + json.dumps(orders))

for o in orders:
    if str(o.get('status') or '') != 'executed':
        fail('Expected every leg status executed: ' + json.dumps(orders))

if str(r2.get('pairExecutionId') or '') != str(pair_id):
    fail('pairExecutionId mismatch on replay')

# Trader leg → Trade with buyOrderId (Variant A: TRADER leg skips pool allocation only)
trader_order_id = None
for o in r2.get('orders') or []:
    if str(o.get('legType') or '') == 'TRADER':
        trader_order_id = o.get('orderId')
        break
if not trader_order_id:
    fail('Could not find TRADER leg in replay orders: ' + json.dumps(r2.get('orders')))

if open_trades_raw.get('code') or open_trades_raw.get('error'):
    fail('getOpenTrades failed: ' + json.dumps(open_trades_raw))
if 'result' not in open_trades_raw:
    fail('getOpenTrades missing result: ' + json.dumps(open_trades_raw))

trades = open_trades_raw['result'].get('trades') or []
matched = [
    t for t in trades
    if str(t.get('buyOrderId') or '') == str(trader_order_id)
]
if not matched:
    fail(
        'No open trade with buyOrderId='
        + str(trader_order_id)
        + ' in getOpenTrades; got '
        + str(len(trades))
        + ' trades'
    )

r1 = first.get('result') or {}
print(
    '[e2e] First call: idempotentReplay='
    + str(r1.get('idempotentReplay'))
    + ' status='
    + str(r1.get('status'))
)
print(
    '[e2e] getOpenTrades: found trade for TRADER buyOrderId '
    + str(trader_order_id)
    + ' (objectId='
    + str(matched[0].get('objectId'))
    + ')'
)
print(
    '[e2e] PASS: replay shows COMMITTED + both legs executed '
    '(server finalize + Order triggers ran).'
)
PY
