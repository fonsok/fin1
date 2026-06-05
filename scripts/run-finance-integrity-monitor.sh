#!/usr/bin/env bash
set -euo pipefail

# Server-local finance integrity monitor (SSOT for iobox — GitHub cloud runners cannot reach LAN Parse).
# Calls getFinanceIntegrityStatus via localhost Parse + master key.
#
# Usage on iobox:
#   ~/fin1-server/scripts/run-finance-integrity-monitor.sh
# Cron (weekly, after snapshots):
#   15 6 * * 1 /home/io/fin1-server/scripts/run-finance-integrity-monitor.sh >> /home/io/fin1-server/logs/finance-integrity-monitor.log 2>&1

BASE_DIR="${BASE_DIR:-/home/io/fin1-server}"
LOG_FILE="${LOG_FILE:-$BASE_DIR/logs/finance-integrity-monitor.log}"
HEARTBEAT_FILE="${HEARTBEAT_FILE:-$BASE_DIR/logs/finance-integrity-monitor.heartbeat}"
ALERT_FILE="${ALERT_FILE:-$BASE_DIR/logs/finance-integrity-monitor.alert}"
MONITOR_ENV_FILE="${MONITOR_ENV_FILE:-$BASE_DIR/scripts/monitor.env}"

if [[ -f "$MONITOR_ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$MONITOR_ENV_FILE"
  set +a
fi

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

PARSE_SERVER_URL="${PARSE_SERVER_URL:-http://127.0.0.1:1338/parse}"
PARSE_APP_ID="${PARSE_APP_ID:-fin1-app-id}"

if [[ -z "${PARSE_MASTER_KEY:-}" ]]; then
  if command -v docker >/dev/null 2>&1; then
    PARSE_MASTER_KEY="$(docker exec fin1-parse-server printenv PARSE_SERVER_MASTER_KEY 2>/dev/null || true)"
  fi
fi

if [[ -z "${PARSE_MASTER_KEY:-}" ]]; then
  echo "[$(timestamp)] ERROR: PARSE_MASTER_KEY not set and docker read failed" | tee -a "$LOG_FILE"
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_JS="${MONITOR_JS:-$SCRIPT_DIR/monitor-finance-integrity.js}"
if [[ ! -f "$MONITOR_JS" ]]; then
  echo "[$(timestamp)] ERROR: missing $MONITOR_JS" | tee -a "$LOG_FILE"
  exit 2
fi

mkdir -p "$(dirname "$LOG_FILE")"

overall_rc=0
{
  echo "[$(timestamp)] START finance-integrity monitor url=$PARSE_SERVER_URL"
  if PARSE_SERVER_URL="$PARSE_SERVER_URL" \
    PARSE_APP_ID="$PARSE_APP_ID" \
    PARSE_MASTER_KEY="$PARSE_MASTER_KEY" \
    node "$MONITOR_JS"; then
    echo "[$(timestamp)] OK finance-integrity healthy"
    echo "status=healthy checkedAt=$(timestamp)" > "$HEARTBEAT_FILE"
    rm -f "$ALERT_FILE"
  else
    overall_rc=$?
    echo "[$(timestamp)] ALERT finance-integrity monitor failed rc=$overall_rc"
    echo "status=degraded checkedAt=$(timestamp) rc=$overall_rc" > "$ALERT_FILE"
    logger -t fin1-finance-integrity "ALERT monitor failed rc=$overall_rc — see $LOG_FILE" 2>/dev/null || true
  fi
  echo "[$(timestamp)] END finance-integrity monitor rc=$overall_rc"
} >> "$LOG_FILE" 2>&1

exit "$overall_rc"
