#!/usr/bin/env bash
set -euo pipefail

# Idempotent crontab entries for all iobox Parse-cloud monitors (user io).
# GitHub cloud runners cannot reach private LAN Parse — server cron is SSOT.
#
#   scripts/install-iobox-monitors-cron.sh

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
BASE_DIR="${FIN1_SERVER_BASE_DIR:-/home/io/fin1-server}"

# marker|cron line
CRON_ENTRIES=(
  "# FIN1 return-percentage-contract-monitor (managed)|12 5 * * * $BASE_DIR/scripts/run-return-percentage-contract-monitor.sh"
  "# FIN1 admin-list-search-health-monitor (managed)|30 5 * * 1 $BASE_DIR/scripts/run-admin-list-search-health-monitor.sh"
  "# FIN1 mirror-basis-drift-monitor (managed)|45 5 * * 1 $BASE_DIR/scripts/run-mirror-basis-drift-monitor.sh"
  "# FIN1 paired-order-status-monitor (managed)|55 5 * * 1 $BASE_DIR/scripts/run-paired-order-status-monitor.sh"
  "# FIN1 trader-pool-bid-ask-contract-monitor (managed)|5 6 * * 1 $BASE_DIR/scripts/run-trader-pool-bid-ask-contract-monitor.sh"
  "# FIN1 summary-report-performance-monitor (managed)|20 6 * * 1 $BASE_DIR/scripts/run-summary-report-performance-monitor.sh"
  "# FIN1 settlement-gl-reconciliation-monitor (managed)|35 6 * * 1 $BASE_DIR/scripts/run-settlement-gl-reconciliation-monitor.sh"
  "# FIN1 finance-integrity-snapshots (managed)|0 6 * * 1 $BASE_DIR/scripts/run-finance-integrity-snapshots.sh >> $BASE_DIR/logs/finance-integrity-snapshots.log 2>&1"
  "# FIN1 finance-integrity-monitor (managed)|15 6 * * 1 $BASE_DIR/scripts/run-finance-integrity-monitor.sh"
)

RUNNERS=(
  run-parse-cloud-monitor.sh
  run-mirror-basis-drift-monitor.sh
  run-paired-order-status-monitor.sh
  run-return-percentage-contract-monitor.sh
  run-admin-list-search-health-monitor.sh
  run-trader-pool-bid-ask-contract-monitor.sh
  run-summary-report-performance-monitor.sh
  run-settlement-gl-reconciliation-monitor.sh
  run-finance-integrity-monitor.sh
  run-finance-integrity-snapshots.sh
)

REMOTE_SCRIPT="$(cat <<'EOS'
set -euo pipefail
BASE_DIR="__BASE_DIR__"
CRON_ENTRIES=(
__CRON_ENTRIES__
)
RUNNERS=(
__RUNNERS__
)

mkdir -p "$BASE_DIR/logs"
for r in "${RUNNERS[@]}"; do
  chmod +x "$BASE_DIR/scripts/$r" 2>/dev/null || true
done

current="$(crontab -l 2>/dev/null || true)"
add_line() {
  local marker="$1"
  local line="$2"
  if echo "$current" | grep -Fq "$marker"; then
    echo "  keep: $marker"
    return 0
  fi
  current="${current}
$marker
$line"
  echo "  add: $marker"
}

for entry in "${CRON_ENTRIES[@]}"; do
  marker="${entry%%|*}"
  line="${entry#*|}"
  add_line "$marker" "$line"
done

printf '%s\n' "$current" | crontab -
echo "crontab installed ($(crontab -l | grep -c 'FIN1 ' || true) FIN1 managed lines)"
EOS
)"

# Build remote arrays
CRON_LINES=""
for entry in "${CRON_ENTRIES[@]}"; do
  CRON_LINES+="  \"$entry\"
"
done
RUNNER_LINES=""
for r in "${RUNNERS[@]}"; do
  RUNNER_LINES+="  \"$r\"
"
done

REMOTE_SCRIPT="${REMOTE_SCRIPT//__BASE_DIR__/$BASE_DIR}"
REMOTE_SCRIPT="${REMOTE_SCRIPT//__CRON_ENTRIES__/$CRON_LINES}"
REMOTE_SCRIPT="${REMOTE_SCRIPT//__RUNNERS__/$RUNNER_LINES}"

run_remote() {
  echo "=== install iobox monitors cron on ${REMOTE_USER}@${REMOTE_HOST} ==="
  # shellcheck disable=SC2029
  ssh "${REMOTE_USER}@${REMOTE_HOST}" bash -s <<<"$REMOTE_SCRIPT"
}

if [[ "$(hostname -s 2>/dev/null || true)" == "iobox" ]] || [[ -d "$BASE_DIR/backend" && "$(whoami)" == "io" ]]; then
  eval "$REMOTE_SCRIPT"
else
  run_remote
fi

echo "=== done ==="
