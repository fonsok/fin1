#!/usr/bin/env bash
# Drain pending SettlementOutbox rows (ADR-017 async GL posting).
#
# Required env: PARSE_SERVER_URL, PARSE_APP_ID, PARSE_MASTER_KEY
# Optional: SETTLEMENT_GL_OUTBOX_LIMIT (default 50)
#
set -euo pipefail

LIMIT="${SETTLEMENT_GL_OUTBOX_LIMIT:-50}"

normalize_parse_base() {
  local url="${1:-}"
  url="${url%/}"
  if [[ -z "$url" ]]; then
    echo ""
    return
  fi
  if [[ "$url" == */parse ]]; then
    echo "$url"
  else
    echo "${url}/parse"
  fi
}

PARSE_BASE="$(normalize_parse_base "${PARSE_SERVER_URL:-}")"
APP_ID="${PARSE_APP_ID:-}"
MASTER_KEY="${PARSE_MASTER_KEY:-}"

if [[ -z "$PARSE_BASE" || -z "$APP_ID" || -z "$MASTER_KEY" ]]; then
  echo "Missing PARSE_SERVER_URL, PARSE_APP_ID, or PARSE_MASTER_KEY" >&2
  exit 1
fi

RESPONSE="$(curl -sk -X POST "${PARSE_BASE}/functions/runSettlementGLOutbox" \
  -H "X-Parse-Application-Id: ${APP_ID}" \
  -H "X-Parse-Master-Key: ${MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "import json; print(json.dumps({'limit': int('${LIMIT}')}))")")"

python3 -c "
import json, sys
raw = json.loads(sys.argv[1])
if raw.get('code') or raw.get('error'):
    raise SystemExit('Parse error: ' + json.dumps(raw))
r = raw.get('result') or {}
processed = int(r.get('processed') or 0)
print(f'processed={processed}')
print(f'ran_at={r.get(\"ranAt\", \"\")}')
if processed == 0:
    print('OK: no pending SettlementOutbox rows')
else:
    print('OK: drained', processed, 'row(s)')
" "$RESPONSE"
