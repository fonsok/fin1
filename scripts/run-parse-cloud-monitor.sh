#!/usr/bin/env bash
set -euo pipefail

# Generic server-local Parse Cloud monitor runner (iobox SSOT).
# Usage: run-parse-cloud-monitor.sh <slug> <monitor.js>
#   slug → logs/<slug>.log, logs/<slug>.heartbeat, logs/<slug>.alert
#
# Required on iobox: node, docker (for master key). Optional: scripts/monitor.env

MONITOR_SLUG="${1:?usage: run-parse-cloud-monitor.sh <slug> <monitor.js>}"
MONITOR_JS_NAME="${2:?usage: run-parse-cloud-monitor.sh <slug> <monitor.js>}"

BASE_DIR="${BASE_DIR:-/home/io/fin1-server}"
LOG_FILE="${LOG_FILE:-$BASE_DIR/logs/${MONITOR_SLUG}.log}"
HEARTBEAT_FILE="${HEARTBEAT_FILE:-$BASE_DIR/logs/${MONITOR_SLUG}.heartbeat}"
ALERT_FILE="${ALERT_FILE:-$BASE_DIR/logs/${MONITOR_SLUG}.alert}"
MONITOR_ENV_FILE="${MONITOR_ENV_FILE:-$BASE_DIR/scripts/monitor.env}"
LOGGER_TAG="${LOGGER_TAG:-fin1-${MONITOR_SLUG}}"

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
MONITOR_JS="${MONITOR_JS:-$SCRIPT_DIR/$MONITOR_JS_NAME}"
if [[ ! -f "$MONITOR_JS" ]]; then
  echo "[$(timestamp)] ERROR: missing $MONITOR_JS" | tee -a "$LOG_FILE"
  exit 2
fi

mkdir -p "$(dirname "$LOG_FILE")"

send_slack_alert() {
  local message="$1"
  local webhook="${RETURN_MONITOR_SLACK_WEBHOOK_URL:-}"
  [[ -n "$webhook" ]] || return 0
  if command -v curl >/dev/null 2>&1; then
    curl -sS -X POST "$webhook" \
      -H "Content-Type: application/json" \
      --data "{\"text\":\"$message\"}" >/dev/null 2>&1 || true
  fi
}

overall_rc=0
{
  echo "[$(timestamp)] START ${MONITOR_SLUG} url=$PARSE_SERVER_URL script=$MONITOR_JS_NAME"
  if PARSE_SERVER_URL="$PARSE_SERVER_URL" \
    PARSE_APP_ID="$PARSE_APP_ID" \
    PARSE_MASTER_KEY="$PARSE_MASTER_KEY" \
    node "$MONITOR_JS"; then
    echo "[$(timestamp)] OK ${MONITOR_SLUG} healthy"
    echo "status=healthy checkedAt=$(timestamp)" > "$HEARTBEAT_FILE"
    rm -f "$ALERT_FILE"
  else
    overall_rc=$?
    echo "[$(timestamp)] ALERT ${MONITOR_SLUG} failed rc=$overall_rc"
    echo "status=degraded checkedAt=$(timestamp) rc=$overall_rc" > "$ALERT_FILE"
    logger -t "$LOGGER_TAG" "ALERT monitor failed rc=$overall_rc — see $LOG_FILE" 2>/dev/null || true
    send_slack_alert "FIN1 ${MONITOR_SLUG} monitor failed (rc=$overall_rc). Log: $LOG_FILE"
  fi
  echo "[$(timestamp)] END ${MONITOR_SLUG} rc=$overall_rc"
} >> "$LOG_FILE" 2>&1

exit "$overall_rc"
