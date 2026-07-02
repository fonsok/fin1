#!/usr/bin/env bash
# Parallel executePairedBuy load probe (unique clientOrderIntentId per request).
# Does NOT run commit/finalize — measures paired-buy creation throughput only.
#
# Env:
#   PARSE_SERVER_URL, PARSE_APPLICATION_ID
#   E2E_TRADER_USERNAME, E2E_TRADER_PASSWORD
#   PAIRED_LOAD_CONCURRENCY (default: 10; roadmap target 50)
#   PAIRED_LOAD_PRICE (default: 100)
#
# Requirements: curl, python3, bash 4+ (wait -n)
set -euo pipefail

PARSE_URL="${PARSE_SERVER_URL:-https://192.168.178.20/parse}"
APP_ID="${PARSE_APPLICATION_ID:-fin1-app-id}"
TRADER_USER="${E2E_TRADER_USERNAME:-trader1@test.com}"
TRADER_PASS="${E2E_TRADER_PASSWORD:-TestPassword123!}"
CONCURRENCY="${PAIRED_LOAD_CONCURRENCY:-10}"
PRICE="${PAIRED_LOAD_PRICE:-100}"

if ! [[ "${CONCURRENCY}" =~ ^[0-9]+$ ]] || [[ "${CONCURRENCY}" -lt 1 ]]; then
  echo "PAIRED_LOAD_CONCURRENCY must be a positive integer" >&2
  exit 1
fi

echo "[load] Parse URL: ${PARSE_URL}"
echo "[load] Trader: ${TRADER_USER}"
echo "[load] Concurrency: ${CONCURRENCY}"

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
print(d['sessionToken'])
" "${LOGIN_JSON}")"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

START_EPOCH="$(date +%s)"
export PAIRED_LOAD_PRICE="${PRICE}"

curl -sk -X POST "${PARSE_URL}/classes/MarketData" \
  -H "X-Parse-Application-Id: ${APP_ID}" \
  -H "X-Parse-Session-Token: ${SESSION}" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "
import json, os
from datetime import datetime, timezone
print(json.dumps({
  'symbol': 'LOAD-PAIRED-WKN',
  'price': float(os.environ.get('PAIRED_LOAD_PRICE', '100')),
  'exchange': 'LOAD',
  'timestamp': {'__type': 'Date', 'iso': datetime.now(timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z')},
}))
")" >/dev/null

echo "[load] MarketData seeded for LOAD-PAIRED-WKN @ ${PRICE}"

for i in $(seq 1 "${CONCURRENCY}"); do
  (
    export INTENT="load-paired-${START_EPOCH}-${i}-$$"
    PAYLOAD="$(python3 -c '
import json, os
print(json.dumps({
  "symbol": "LOAD-PAIRED-WKN",
  "orderInstruction": "market",
  "clientOrderIntentId": os.environ["INTENT"],
  "traderQuantity": 1,
  "mirrorPoolQuantity": 1,
  "description": "Load test paired buy",
}))
')"
    OUT="${WORKDIR}/resp-${i}.json"
    HTTP_CODE="$(curl -sk -o "${OUT}" -w '%{http_code}' -X POST "${PARSE_URL}/functions/executePairedBuy" \
      -H "X-Parse-Application-Id: ${APP_ID}" \
      -H "X-Parse-Session-Token: ${SESSION}" \
      -H "Content-Type: application/json" \
      -d "${PAYLOAD}")"
    echo "${HTTP_CODE}" > "${WORKDIR}/http-${i}.txt"
  ) &
done

wait

END_EPOCH="$(date +%s)"
ELAPSED="$((END_EPOCH - START_EPOCH))"

OK=0
FAIL=0
for i in $(seq 1 "${CONCURRENCY}"); do
  HTTP="$(cat "${WORKDIR}/http-${i}.txt")"
  if python3 -c "
import json, sys
raw = json.load(open(sys.argv[1]))
http = sys.argv[2]
ok = http == '200' and 'result' in raw and raw['result'].get('pairExecutionId')
sys.exit(0 if ok else 1)
" "${WORKDIR}/resp-${i}.json" "${HTTP}" 2>/dev/null; then
    OK=$((OK + 1))
  else
    FAIL=$((FAIL + 1))
    echo "[load] fail #${i} http=${HTTP}" >&2
    head -c 400 "${WORKDIR}/resp-${i}.json" >&2 || true
    echo >&2
  fi
done

echo "[load] done: ok=${OK} fail=${FAIL} elapsed=${ELAPSED}s concurrency=${CONCURRENCY}"

if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi
