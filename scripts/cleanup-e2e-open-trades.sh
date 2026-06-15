#!/usr/bin/env bash
# Remove orphan open E2E test trades (symbol prefix E2E-) from a trader depot.
#
# Required: PARSE_SERVER_URL, PARSE_APP_ID, PARSE_MASTER_KEY
# Optional: E2E_TRADER_ID (Parse user id) — if unset, cleans all traders
#           DRY_RUN=1 (default) — set DRY_RUN=0 to delete
#
set -euo pipefail

PARSE_URL="${PARSE_SERVER_URL:-https://192.168.178.20/parse}"
APP_ID="${PARSE_APPLICATION_ID:-fin1-app-id}"
MASTER_KEY="${PARSE_MASTER_KEY:-}"
DRY_RUN="${DRY_RUN:-1}"
TRADER_ID="${E2E_TRADER_ID:-}"

if [[ -z "$MASTER_KEY" ]]; then
  echo "PARSE_MASTER_KEY required (e.g. from server: docker exec fin1-parse-server printenv PARSE_SERVER_MASTER_KEY)" >&2
  exit 1
fi

PARSE_URL="${PARSE_URL%/}"
[[ "$PARSE_URL" == */parse ]] || PARSE_URL="${PARSE_URL}/parse"

PAYLOAD="$(python3 -c "
import json, os
p = {}
if os.environ.get('TRADER_ID', '').strip():
    p['traderId'] = os.environ['TRADER_ID'].strip()
if os.environ.get('DRY_RUN', '1') in ('0', 'false', 'False'):
    p['dryRun'] = False
else:
    p['dryRun'] = True
print(json.dumps(p))
" )"

RESPONSE="$(curl -sk -X POST "${PARSE_URL}/functions/cleanupE2EOpenTrades" \
  -H "X-Parse-Application-Id: ${APP_ID}" \
  -H "X-Parse-Master-Key: ${MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}")"

python3 -c "
import json, sys
raw = json.loads(sys.argv[1])
if raw.get('code') or raw.get('error'):
    raise SystemExit('Parse error: ' + json.dumps(raw))
r = raw.get('result') or {}
print('dry_run=', r.get('dryRun'))
print('matched=', r.get('matched'))
for row in r.get('results') or []:
    print(row.get('action'), 'trade#', row.get('tradeNumber'), row.get('symbol'), 'rem=', row.get('remainingQuantity'))
if r.get('dryRun') and int(r.get('matched') or 0) > 0:
    print('Hint: DRY_RUN=0 to apply deletes')
" "$RESPONSE"
