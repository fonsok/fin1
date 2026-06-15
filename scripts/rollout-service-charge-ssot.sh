#!/usr/bin/env bash
# Flip live Configuration to ADR-007 Phase-2 service-charge SSOT (no 4-eyes for display flags).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
if [ -z "${BA_PASSWORD:-}" ] && [ -f "$SCRIPT_DIR/.env.server" ]; then
  set +e
  source "$SCRIPT_DIR/.env.server" 2>/dev/null || true
  set -e
fi

PARSE_HOST="${FIN1_PARSE_CLOUD_SSH_HOST:-${FIN1_SERVER_IP:-192.168.178.20}}"
PARSE_URL="${PARSE_URL:-https://${PARSE_HOST}/parse}"
APP_ID="${PARSE_SERVER_APPLICATION_ID:-fin1-app-id}"
ADMIN_EMAIL="${SMOKE_ADMIN_EMAIL:-admin@fin1.de}"
REASON="${ROLLOUT_REASON:-ADR-007 Phase 2 service-charge SSOT rollout}"

if [ -z "${BA_PASSWORD:-}" ]; then
  echo "FAIL: BA_PASSWORD not set (scripts/.env.server)" >&2
  exit 2
fi

echo "=== rollout-service-charge-ssot ==="
echo "  PARSE_URL=$PARSE_URL"

LOGIN="$(curl -sk --connect-timeout 15 -X POST "${PARSE_URL}/login" \
  -H "X-Parse-Application-Id: ${APP_ID}" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${ADMIN_EMAIL}\",\"password\":\"${BA_PASSWORD}\"}")"

TOKEN="$(echo "$LOGIN" | python3 -c "import json,sys; print(json.load(sys.stdin).get('sessionToken',''))" 2>/dev/null || true)"
if [ -z "$TOKEN" ]; then
  echo "FAIL: admin login" >&2
  exit 1
fi
echo "  OK admin login"

apply_flag() {
  local param="$1"
  local value="$2"
  local resp
  resp="$(curl -sk --connect-timeout 30 -X POST "${PARSE_URL}/functions/requestConfigurationChange" \
    -H "X-Parse-Application-Id: ${APP_ID}" \
    -H "X-Parse-Session-Token: ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"parameterName\":\"${param}\",\"newValue\":${value},\"reason\":\"${REASON}\"}")"
  local ok
  ok="$(echo "$resp" | python3 -c "import json,sys; r=json.load(sys.stdin).get('result',{}); print('1' if r.get('success') else '0')" 2>/dev/null || echo 0)"
  if [ "$ok" != "1" ]; then
    echo "FAIL: requestConfigurationChange ${param}=${value}" >&2
    echo "$resp" | python3 -m json.tool 2>/dev/null || echo "$resp"
    exit 1
  fi
  echo "  OK ${param}=${value}"
}

apply_flag serviceChargeInvoiceFromBackend 1
apply_flag serviceChargeLegacyClientFallbackEnabled 0

CONFIG="$(curl -sk --connect-timeout 30 -X POST "${PARSE_URL}/functions/getConfig" \
  -H "X-Parse-Application-Id: ${APP_ID}" \
  -H "Content-Type: application/json" \
  -d '{"environment":"production"}')"

echo "$CONFIG" | python3 -c "
import json,sys
d=json.load(sys.stdin).get('result',{}).get('display',{})
print('  verify serviceChargeInvoiceFromBackend=', d.get('serviceChargeInvoiceFromBackend'))
print('  verify serviceChargeLegacyClientFallbackEnabled=', d.get('serviceChargeLegacyClientFallbackEnabled'))
"

echo "OK: service-charge SSOT rollout applied."
