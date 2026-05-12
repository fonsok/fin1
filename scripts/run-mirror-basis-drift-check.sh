#!/usr/bin/env bash
set -euo pipefail

# Weekly mirror-basis drift check wrapper.
# Compares stored `metadata.returnPercentage` on investorCollectionBill docs
# against `deriveMirrorTradeBasis(buyLeg, sellLeg, commissionRate)`. Healthy
# systems should report drift=0 after the 2026-04-23 Phase-A deploy.

BASE_DIR="${BASE_DIR:-/home/io/fin1-server}"
BACKEND_DIR="$BASE_DIR/backend"
COMPOSE_FILE="${COMPOSE_FILE:-$BASE_DIR/docker-compose.production.yml}"
SCRIPT_PATH="${SCRIPT_PATH:-$BACKEND_DIR/scripts/weekly-mirror-basis-drift-check.js}"
LOG_FILE="${LOG_FILE:-$BASE_DIR/logs/mirror-basis-drift.log}"
STATE_FILE="${STATE_FILE:-$BASE_DIR/logs/mirror-basis-drift.last-run}"
ALERT_FILE="${ALERT_FILE:-$BASE_DIR/logs/mirror-basis-drift.alert}"
MAX_AGE_SECONDS="${MAX_AGE_SECONDS:-691200}" # 8 days
CATCHUP_MODE="false"

if [[ "${1:-}" == "--catchup" ]]; then
  CATCHUP_MODE="true"
fi

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
epoch_now() { date -u +%s; }

if [[ "$CATCHUP_MODE" == "true" && -f "$STATE_FILE" ]]; then
  LAST_RUN_EPOCH="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
  NOW_EPOCH="$(epoch_now)"
  AGE=$(( NOW_EPOCH - LAST_RUN_EPOCH ))
  if (( AGE >= 0 && AGE < MAX_AGE_SECONDS )); then
    echo "[$(timestamp)] SKIP: mirror-basis drift catch-up not needed (last run ${AGE}s ago, max=${MAX_AGE_SECONDS}s)" >> "$LOG_FILE"
    exit 0
  fi
fi

MONGO_PASSWORD="$(python3 - <<'PY'
from pathlib import Path
env = {}
for raw in Path("/home/io/fin1-server/backend/.env").read_text().splitlines():
    line = raw.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    k, v = line.split("=", 1)
    env[k.strip()] = v
print(env.get("MONGO_INITDB_ROOT_PASSWORD", ""))
PY
)"

if [[ -z "$MONGO_PASSWORD" ]]; then
  echo "[$(timestamp)] ERROR: MONGO_INITDB_ROOT_PASSWORD not found in .env" >> "$LOG_FILE"
  exit 2
fi

mkdir -p "$(dirname "$LOG_FILE")"

{
  echo "[$(timestamp)] START mirror-basis drift check"
  OUTPUT="$(cd "$BASE_DIR" && docker compose -f "$COMPOSE_FILE" exec -T mongodb \
    mongosh --quiet --username admin --password "$MONGO_PASSWORD" \
    --authenticationDatabase admin fin1 < "$SCRIPT_PATH" 2>&1)"
  rc=$?
  echo "$OUTPUT"
  echo "[$(timestamp)] END mirror-basis drift check rc=$rc"
  DRIFTED="$(echo "$OUTPUT" | awk -F= '/^driftedDocuments=/{print $2}' | head -1)"
  if [[ -n "$DRIFTED" && "$DRIFTED" != "0" ]]; then
    echo "[$(timestamp)] ALERT: $DRIFTED investorCollectionBill document(s) drifted from mirror-basis SSOT" | tee "$ALERT_FILE"
    logger -t fin1-mirror-basis-drift "ALERT: $DRIFTED drifted documents — see $LOG_FILE"
  else
    rm -f "$ALERT_FILE"
  fi
  if [[ $rc -eq 0 ]]; then
    epoch_now > "$STATE_FILE"
  fi
  exit $rc
} >> "$LOG_FILE" 2>&1
