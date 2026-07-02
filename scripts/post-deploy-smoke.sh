#!/usr/bin/env bash
# Post-deploy smoke suite (run from Mac against iobox, or on server with PARSE_URL set).
#
# Usage:
#   ./scripts/post-deploy-smoke.sh              # full: admin + commission + legal 4-eyes
#   POST_DEPLOY_SMOKE_PROFILE=admin ./scripts/post-deploy-smoke.sh
#   POST_DEPLOY_SMOKE=0 ./scripts/deploy-parse-cloud-to-fin1-server.sh   # skip smokes
#
# Requires BA_PASSWORD in scripts/.env.server (see Documentation/DEV_PORTAL_LOGIN_SSOT.md).
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
PROFILE="${POST_DEPLOY_SMOKE_PROFILE:-full}"
WAIT_SECONDS="${POST_DEPLOY_WAIT_SECONDS:-15}"

health_url="${PARSE_URL%/parse}/parse/health"
if [[ "$PARSE_URL" == http://127.0.0.1:* ]] || [[ "$PARSE_URL" == http://localhost:* ]]; then
  health_url="${PARSE_URL}/health"
fi

wait_for_parse() {
  local max="${1:-$WAIT_SECONDS}"
  local i=0
  echo "▸ waiting for Parse health (up to ${max}s): ${health_url}"
  while [ "$i" -lt "$max" ]; do
    code="$(curl -sk -o /dev/null -w '%{http_code}' --connect-timeout 3 "$health_url" 2>/dev/null || echo 000)"
    if [ "$code" = "200" ]; then
      echo "  OK parse healthy (${i}s)"
      return 0
    fi
    sleep 1
    i=$((i + 1))
  done
  echo "FAIL: Parse not healthy after ${max}s (last HTTP ${code})" >&2
  return 1
}

run_smoke() {
  local name="$1"
  local script="$2"
  local attempts="${POST_DEPLOY_SMOKE_RETRIES:-2}"
  local try=1
  echo ""
  echo "▸ ${name}"
  while [ "$try" -le "$attempts" ]; do
    if bash "$SCRIPT_DIR/$script"; then
      return 0
    fi
    if [ "$try" -lt "$attempts" ]; then
      echo "  retry ${name} (${try}/${attempts}) in 3s …" >&2
      sleep 3
    fi
    try=$((try + 1))
  done
  echo "FAIL: ${name} after ${attempts} attempt(s)" >&2
  return 1
}

inter_smoke_sleep() {
  local sec="${POST_DEPLOY_INTER_SMOKE_SLEEP:-2}"
  if [ "$sec" -gt 0 ]; then
    sleep "$sec"
  fi
}

echo "=== post-deploy-smoke (profile=${PROFILE}) ==="
echo "  PARSE_URL=${PARSE_URL}"

if [ "${POST_DEPLOY_WAIT_PARSE:-1}" != "0" ]; then
  wait_for_parse "$WAIT_SECONDS"
fi

case "$PROFILE" in
  full)
    run_smoke "admin getUserDetails" "smoke-admin-get-user-details.sh"
    inter_smoke_sleep
    run_smoke "growth dashboard" "smoke-growth-dashboard.sh"
    inter_smoke_sleep
    run_smoke "marketing spend import" "smoke-marketing-spend-import.sh"
    inter_smoke_sleep
    run_smoke "user acquisition" "smoke-user-acquisition-e2e.sh"
    inter_smoke_sleep
    run_smoke "commission 4-eyes E2E" "smoke-commission-rate-bundle-e2e.sh"
    inter_smoke_sleep
    run_smoke "user commission 4-eyes E2E" "smoke-user-commission-rate-bundle-e2e.sh"
    inter_smoke_sleep
    run_smoke "user app service charge 4-eyes E2E" "smoke-user-app-service-charge-e2e.sh"
    inter_smoke_sleep
    run_smoke "user open depot limit 4-eyes E2E" "smoke-user-open-depot-limit-e2e.sh"
    inter_smoke_sleep
    run_smoke "upsertMarketDataQuote E2E" "smoke-publish-market-data-quote-e2e.sh"
    inter_smoke_sleep
    run_smoke "market data feed E2E" "smoke-market-data-feed-e2e.sh"
    inter_smoke_sleep
    run_smoke "min trader buy order 4-eyes E2E" "smoke-min-trader-buy-order-e2e.sh"
    inter_smoke_sleep
    run_smoke "legalAppName 4-eyes E2E" "smoke-legal-app-name-e2e.sh"
    ;;
  admin)
    run_smoke "admin getUserDetails" "smoke-admin-get-user-details.sh"
    inter_smoke_sleep
    run_smoke "growth dashboard" "smoke-growth-dashboard.sh"
    inter_smoke_sleep
    run_smoke "marketing spend import" "smoke-marketing-spend-import.sh"
    inter_smoke_sleep
    run_smoke "user acquisition" "smoke-user-acquisition-e2e.sh"
    ;;
  parse)
    run_smoke "commission 4-eyes E2E" "smoke-commission-rate-bundle-e2e.sh"
    inter_smoke_sleep
    run_smoke "user commission 4-eyes E2E" "smoke-user-commission-rate-bundle-e2e.sh"
    inter_smoke_sleep
    run_smoke "user app service charge 4-eyes E2E" "smoke-user-app-service-charge-e2e.sh"
    inter_smoke_sleep
    run_smoke "user open depot limit 4-eyes E2E" "smoke-user-open-depot-limit-e2e.sh"
    inter_smoke_sleep
    run_smoke "upsertMarketDataQuote E2E" "smoke-publish-market-data-quote-e2e.sh"
    inter_smoke_sleep
    run_smoke "market data feed E2E" "smoke-market-data-feed-e2e.sh"
    inter_smoke_sleep
    run_smoke "min trader buy order 4-eyes E2E" "smoke-min-trader-buy-order-e2e.sh"
    inter_smoke_sleep
    run_smoke "legalAppName 4-eyes E2E" "smoke-legal-app-name-e2e.sh"
    ;;
  none)
    echo "  skip (profile=none)"
    exit 0
    ;;
  *)
    echo "FAIL: unknown POST_DEPLOY_SMOKE_PROFILE=${PROFILE} (use full|admin|parse|none)" >&2
    exit 2
    ;;
esac

echo ""
echo "OK: post-deploy-smoke passed (profile=${PROFILE})."
