#!/usr/bin/env bash
# Deploy Parse Cloud Code to iobox: shadow check, rsync cloud/, remove configHelper.js shadow, restart parse-server.
# Host: FIN1_PARSE_CLOUD_SSH_HOST or 192.168.178.24 (see Documentation/OPERATIONAL_DEPLOY_HOSTS.md).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
if [[ -f "$SCRIPT_DIR/.env.server" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/.env.server"
  set +a
fi

REMOTE_USER="${FIN1_SERVER_USER:-io}"
CANONICAL_DEFAULT_CLOUD_HOST="192.168.178.24"
REMOTE_HOST="${FIN1_PARSE_CLOUD_SSH_HOST:-$CANONICAL_DEFAULT_CLOUD_HOST}"
REMOTE_CLOUD="~/fin1-server/backend/parse-server/cloud/"
# Schrittweiser Deploy-Ausbau: Manifest (Git-SHA + Cloud-Tree-Hash) auf den Server schreiben (0=aus).
WRITE_DEPLOY_MANIFEST="${WRITE_DEPLOY_MANIFEST:-1}"

echo "=== Parse Cloud deploy → ${REMOTE_USER}@${REMOTE_HOST} ==="
echo ""

"$SCRIPT_DIR/check-parse-cloud-config-helper-shadow.sh"
"$SCRIPT_DIR/check-parse-cloud-aggregate-key-access.sh"

echo "▸ sync shared/contracts → cloud/contracts (App-Ledger SSOT inside Parse mount) …"
mkdir -p "$PROJECT_ROOT/backend/parse-server/cloud/contracts"
cp "$PROJECT_ROOT/shared/contracts/appLedgerTransactionTypes.json" \
  "$PROJECT_ROOT/backend/parse-server/cloud/contracts/appLedgerTransactionTypes.json"
cp "$PROJECT_ROOT/shared/contracts/signUpStepNumbers.json" \
  "$PROJECT_ROOT/backend/parse-server/cloud/contracts/signUpStepNumbers.json"

echo "▸ rsync cloud/ (exclude Jest tests: __tests__, *.test.js) …"
rsync -avz \
  --exclude='__tests__' \
  --exclude='*.test.js' \
  "$PROJECT_ROOT/backend/parse-server/cloud/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_CLOUD}"

echo "▸ sync ops scripts (integrity indexes + snapshot checks) …"
# shellcheck disable=SC2029
ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ~/fin1-server/scripts ~/fin1-server/scripts/lib ~/fin1-server/backend/scripts/lib"
rsync -avz \
  "$PROJECT_ROOT/backend/scripts/ensure-paired-execution-indexes.js" \
  "${REMOTE_USER}@${REMOTE_HOST}:~/fin1-server/scripts/ensure-paired-execution-indexes.js"
rsync -avz \
  "$PROJECT_ROOT/backend/scripts/ensure-finance-integrity-indexes.js" \
  "$PROJECT_ROOT/backend/scripts/verify-finance-integrity-indexes.js" \
  "$PROJECT_ROOT/backend/scripts/weekly-mirror-basis-drift-check.js" \
  "$PROJECT_ROOT/backend/scripts/weekly-trader-cash-booking-duplicate-check.js" \
  "${REMOTE_USER}@${REMOTE_HOST}:~/fin1-server/backend/scripts/"
rsync -avz \
  "$PROJECT_ROOT/backend/scripts/lib/" \
  "${REMOTE_USER}@${REMOTE_HOST}:~/fin1-server/backend/scripts/lib/"
rsync -avz \
  "$PROJECT_ROOT/scripts/run-parse-cloud-monitor.sh" \
  "$PROJECT_ROOT/scripts/run-finance-integrity-snapshots.sh" \
  "$PROJECT_ROOT/scripts/run-mirror-basis-drift-check.sh" \
  "$PROJECT_ROOT/scripts/run-finance-integrity-monitor.sh" \
  "$PROJECT_ROOT/scripts/run-mirror-basis-drift-monitor.sh" \
  "$PROJECT_ROOT/scripts/run-paired-order-status-monitor.sh" \
  "$PROJECT_ROOT/scripts/run-return-percentage-contract-monitor.sh" \
  "$PROJECT_ROOT/scripts/run-return-monitor.sh" \
  "$PROJECT_ROOT/scripts/run-admin-list-search-health-monitor.sh" \
  "$PROJECT_ROOT/scripts/run-trader-pool-bid-ask-contract-monitor.sh" \
  "$PROJECT_ROOT/scripts/run-summary-report-performance-monitor.sh" \
  "$PROJECT_ROOT/scripts/monitor-finance-integrity.js" \
  "$PROJECT_ROOT/scripts/monitor-mirror-basis-drift-contract.js" \
  "$PROJECT_ROOT/scripts/monitor-paired-order-status-integrity.js" \
  "$PROJECT_ROOT/scripts/monitor-return-percentage-contract.js" \
  "$PROJECT_ROOT/scripts/monitor-trader-pool-bid-ask-contract.js" \
  "$PROJECT_ROOT/scripts/monitor-summary-report-performance.js" \
  "$PROJECT_ROOT/scripts/monitor-settlement-gl-reconciliation.js" \
  "$PROJECT_ROOT/scripts/run-settlement-gl-reconciliation-monitor.sh" \
  "$PROJECT_ROOT/scripts/monitor-admin-list-search-health.js" \
  "$PROJECT_ROOT/scripts/e2e-paired-sell-integrity-smoke.js" \
  "$PROJECT_ROOT/scripts/post-deploy-smoke.sh" \
  "$PROJECT_ROOT/scripts/smoke-admin-get-user-details.sh" \
  "$PROJECT_ROOT/scripts/smoke-commission-rate-bundle-e2e.sh" \
  "$PROJECT_ROOT/scripts/smoke-legal-app-name-e2e.sh" \
  "$PROJECT_ROOT/scripts/run-onboarding-signup-indexes-migration.sh" \
  "$PROJECT_ROOT/scripts/load-test-signup-onboarding.js" \
  "$PROJECT_ROOT/scripts/run-signup-onboarding-load-test.sh" \
  "${REMOTE_USER}@${REMOTE_HOST}:~/fin1-server/scripts/"

echo "▸ remove configHelper.js shadow (if any) + restart parse-server …"
ssh "${REMOTE_USER}@${REMOTE_HOST}" "rm -f ~/fin1-server/backend/parse-server/cloud/utils/configHelper.js && cd ~/fin1-server && docker compose -f docker-compose.production.yml restart parse-server"

if [[ "${WRITE_DEPLOY_MANIFEST}" != "0" ]]; then
  echo "▸ deploy manifest (~/fin1-server/deploy-manifests/) …"
  MANIFEST_JSON="$("$SCRIPT_DIR/write-deploy-manifest.sh" --component parse-cloud)"
  # shellcheck disable=SC2029
  ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ~/fin1-server/deploy-manifests && cat > ~/fin1-server/deploy-manifests/parse-cloud-latest.json" <<<"$MANIFEST_JSON"
  # shellcheck disable=SC2029
  ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ~/fin1-server/deploy-manifests && cat >> ~/fin1-server/deploy-manifests/history.log" <<<"$(printf '%s %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$(echo "$MANIFEST_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["gitCommit"])')")"
fi

echo "▸ install iobox monitor cron (idempotent) …"
"$SCRIPT_DIR/install-iobox-monitors-cron.sh"

if [[ "${POST_DEPLOY_SMOKE:-1}" != "0" ]]; then
  echo ""
  echo "▸ post-deploy smoke (Parse Cloud, via server localhost) …"
  if [[ -z "${BA_PASSWORD:-}" ]]; then
    echo "  WARN: BA_PASSWORD unset — skipping post-deploy smoke (set in scripts/.env.server)" >&2
  else
    # shellcheck disable=SC2029
    ssh "${REMOTE_USER}@${REMOTE_HOST}" \
      "cd ~/fin1-server && BA_PASSWORD='${BA_PASSWORD}' PARSE_URL='http://127.0.0.1:1338/parse' POST_DEPLOY_SMOKE_PROFILE='${POST_DEPLOY_SMOKE_PROFILE:-full}' POST_DEPLOY_WAIT_PARSE='${POST_DEPLOY_WAIT_PARSE:-1}' bash scripts/post-deploy-smoke.sh"
  fi
fi

echo ""
echo "=== Parse Cloud deploy done ==="
