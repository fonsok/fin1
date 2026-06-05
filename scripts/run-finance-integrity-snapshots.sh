#!/usr/bin/env bash
set -euo pipefail

# Unified finance-integrity snapshot runner (closed integrity system — detection layer).
# Prepends shared SSOT lib, runs all weekly mongosh checks, writes OpsHealthSnapshot rows.
#
# Checks:
#   - mirror-basis-drift
#   - trader-cash-booking-duplicates

BASE_DIR="${BASE_DIR:-/home/io/fin1-server}"
BACKEND_DIR="${BACKEND_DIR:-$BASE_DIR/backend}"
COMPOSE_FILE="${COMPOSE_FILE:-$BASE_DIR/docker-compose.production.yml}"
LIB_PATH="${LIB_PATH:-$BACKEND_DIR/scripts/lib/opsFinanceSsot.mongodb.js}"
LOG_FILE="${LOG_FILE:-$BASE_DIR/logs/finance-integrity-snapshots.log}"
STATE_FILE="${STATE_FILE:-$BASE_DIR/logs/finance-integrity-snapshots.last-run}"
ALERT_FILE="${ALERT_FILE:-$BASE_DIR/logs/finance-integrity-snapshots.alert}"
MAX_AGE_SECONDS="${MAX_AGE_SECONDS:-691200}" # 8 days
CATCHUP_MODE="false"
CHECK_FILTER="${CHECK_FILTER:-all}"

for arg in "$@"; do
  case "$arg" in
    --catchup) CATCHUP_MODE="true" ;;
    --only=*) CHECK_FILTER="${arg#--only=}" ;;
  esac
done
if [[ "${1:-}" == "--only" && -n "${2:-}" ]]; then
  CHECK_FILTER="$2"
fi

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
epoch_now() { date -u +%s; }

if [[ "$CATCHUP_MODE" == "true" && -f "$STATE_FILE" ]]; then
  LAST_RUN_EPOCH="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
  NOW_EPOCH="$(epoch_now)"
  AGE=$(( NOW_EPOCH - LAST_RUN_EPOCH ))
  if (( AGE >= 0 && AGE < MAX_AGE_SECONDS )); then
    echo "[$(timestamp)] SKIP: finance-integrity catch-up not needed (last run ${AGE}s ago)" >> "$LOG_FILE"
    exit 0
  fi
fi

MONGO_PASSWORD=""
for candidate in "${ENV_FILE:-}" "$BASE_DIR/.env" "$BASE_DIR/backend/.env"; do
  [[ -z "$candidate" || ! -f "$candidate" ]] && continue
  MONGO_PASSWORD="$(grep -E '^MONGO_INITDB_ROOT_PASSWORD=' "$candidate" | tail -1 | cut -d= -f2- | tr -d '"' | tr -d "'")"
  [[ -n "$MONGO_PASSWORD" ]] && break
done

if [[ -z "$MONGO_PASSWORD" ]]; then
  echo "[$(timestamp)] ERROR: MONGO_INITDB_ROOT_PASSWORD not found" >> "$LOG_FILE"
  exit 2
fi

if [[ ! -f "$LIB_PATH" ]]; then
  echo "[$(timestamp)] ERROR: missing SSOT lib $LIB_PATH" >> "$LOG_FILE"
  exit 2
fi

mkdir -p "$(dirname "$LOG_FILE")"

run_check() {
  local name="$1"
  local script_path="$2"
  if [[ ! -f "$script_path" ]]; then
    echo "[$(timestamp)] ERROR: missing script $script_path" >> "$LOG_FILE"
    return 2
  fi
  local combined
  combined="$(mktemp)"
  cat "$LIB_PATH" "$script_path" > "$combined"
  echo "[$(timestamp)] START $name" >> "$LOG_FILE"
  local output rc
  output="$(cd "$BASE_DIR" && docker compose -f "$COMPOSE_FILE" exec -T mongodb \
    mongosh --quiet --username admin --password "$MONGO_PASSWORD" \
    --authenticationDatabase admin fin1 < "$combined" 2>&1)" || rc=$?
  rc="${rc:-0}"
  rm -f "$combined"
  echo "$output" >> "$LOG_FILE"
  echo "[$(timestamp)] END $name rc=$rc" >> "$LOG_FILE"
  return "$rc"
}

{
  echo "[$(timestamp)] START finance-integrity snapshots (filter=$CHECK_FILTER)"
  overall_rc=0

  if [[ "$CHECK_FILTER" == "all" || "$CHECK_FILTER" == "mirror-basis" ]]; then
    run_check "mirror-basis-drift" "$BACKEND_DIR/scripts/weekly-mirror-basis-drift-check.js" || overall_rc=1
  fi

  if [[ "$CHECK_FILTER" == "all" || "$CHECK_FILTER" == "trader-cash-duplicates" ]]; then
    run_check "trader-cash-booking-duplicates" "$BACKEND_DIR/scripts/weekly-trader-cash-booking-duplicate-check.js" || overall_rc=1
  fi

  DRIFTED="$(grep -E '^driftedDocuments=' "$LOG_FILE" | tail -1 | cut -d= -f2- || true)"
  DUPES="$(grep -E '^violationGroups=' "$LOG_FILE" | tail -1 | cut -d= -f2- || true)"
  if [[ "${DRIFTED:-0}" != "0" || "${DUPES:-0}" != "0" ]]; then
    echo "[$(timestamp)] ALERT: finance integrity drifted=${DRIFTED:-?} duplicateGroups=${DUPES:-?}" | tee "$ALERT_FILE"
    logger -t fin1-finance-integrity "ALERT drifted=${DRIFTED:-?} dupes=${DUPES:-?} — see $LOG_FILE"
    overall_rc=1
  else
    rm -f "$ALERT_FILE"
  fi

  if [[ $overall_rc -eq 0 ]]; then
    epoch_now > "$STATE_FILE"
  fi
  echo "[$(timestamp)] END finance-integrity snapshots rc=$overall_rc"
  exit $overall_rc
} >> "$LOG_FILE" 2>&1
