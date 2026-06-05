#!/usr/bin/env bash
# Backfill App-Ledger tradingResidualReturn (+ release correction if needed) for one investment.
#
# Usage:
#   ./scripts/backfill-trading-residual-escrow.sh INV-2026-0000020
#   ./scripts/backfill-trading-residual-escrow.sh --id rCoTzxlTYI
#
# Requires scripts/.env.server (FIN1_PARSE_CLOUD_SSH_HOST, FIN1_SERVER_USER).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
if [[ -f "$SCRIPT_DIR/.env.server" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/.env.server"
  set +a
fi

REMOTE_USER="${FIN1_SERVER_USER:-io}"
REMOTE_HOST="${FIN1_PARSE_CLOUD_SSH_HOST:-192.168.178.24}"
REMOTE_DIR="~/fin1-server"
PARSE_URL="http://127.0.0.1:1338/parse"
APP_ID="${PARSE_APP_ID:-fin1-app-id}"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <investmentNumber> | --id <objectId>" >&2
  exit 1
fi

PAYLOAD='{}'
if [[ "$1" == "--id" ]]; then
  PAYLOAD="$(python3 -c 'import json,sys; print(json.dumps({"investmentId": sys.argv[1]}))' "$2")"
else
  PAYLOAD="$(python3 -c 'import json,sys; print(json.dumps({"investmentNumber": sys.argv[1]}))' "$1")"
fi

echo "=== Backfill trading residual escrow → ${REMOTE_USER}@${REMOTE_HOST} ==="
echo "Payload: $PAYLOAD"
echo ""

RESULT=$(ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd $REMOTE_DIR && \
  MK=\$(grep '^PARSE_SERVER_MASTER_KEY=' backend/.env 2>/dev/null | cut -d= -f2- | tr -d '\r\n'); \
  if [ -z \"\$MK\" ]; then echo '{\"error\":\"PARSE_SERVER_MASTER_KEY missing\"}'; exit 0; fi; \
  curl -s -X POST $PARSE_URL/functions/backfillTradingResidualEscrow \
    -H 'X-Parse-Application-Id: $APP_ID' \
    -H \"X-Parse-Master-Key: \$MK\" \
    -H 'Content-Type: application/json' \
    -d '$PAYLOAD'")

if echo "$RESULT" | grep -q '"code":'; then
  echo "Parse error:" >&2
  echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"
  exit 1
fi

echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"
echo ""
echo "=== Done ==="
