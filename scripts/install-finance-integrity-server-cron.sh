#!/usr/bin/env bash
set -euo pipefail

# Idempotent crontab entries for finance-integrity on iobox (user io).
# Can run locally (SSH) or directly on the server.
#
#   scripts/install-finance-integrity-server-cron.sh
#   FIN1_PARSE_CLOUD_SSH_HOST=192.168.178.20 scripts/install-finance-integrity-server-cron.sh

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

MARKER_SNAPSHOTS="# FIN1 finance-integrity-snapshots (managed)"
MARKER_MONITOR="# FIN1 finance-integrity-monitor (managed)"
CRON_SNAPSHOTS="0 6 * * 1 $BASE_DIR/scripts/run-finance-integrity-snapshots.sh >> $BASE_DIR/logs/finance-integrity-snapshots.log 2>&1"
CRON_MONITOR="15 6 * * 1 $BASE_DIR/scripts/run-finance-integrity-monitor.sh"

REMOTE_SCRIPT="$(cat <<'EOS'
set -euo pipefail
BASE_DIR="__BASE_DIR__"
MARKER_SNAPSHOTS="__MARKER_SNAPSHOTS__"
MARKER_MONITOR="__MARKER_MONITOR__"
CRON_SNAPSHOTS="__CRON_SNAPSHOTS__"
CRON_MONITOR="__CRON_MONITOR__"

mkdir -p "$BASE_DIR/logs"
chmod +x "$BASE_DIR/scripts/run-finance-integrity-snapshots.sh" 2>/dev/null || true
chmod +x "$BASE_DIR/scripts/run-finance-integrity-monitor.sh" 2>/dev/null || true

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

add_line "$MARKER_SNAPSHOTS" "$CRON_SNAPSHOTS"
add_line "$MARKER_MONITOR" "$CRON_MONITOR"

printf '%s\n' "$current" | crontab -
echo "crontab installed ($(crontab -l | grep -c 'FIN1 finance-integrity' || true) finance-integrity lines)"
EOS
)"

REMOTE_SCRIPT="${REMOTE_SCRIPT//__BASE_DIR__/$BASE_DIR}"
REMOTE_SCRIPT="${REMOTE_SCRIPT//__MARKER_SNAPSHOTS__/$MARKER_SNAPSHOTS}"
REMOTE_SCRIPT="${REMOTE_SCRIPT//__MARKER_MONITOR__/$MARKER_MONITOR}"
REMOTE_SCRIPT="${REMOTE_SCRIPT//__CRON_SNAPSHOTS__/$CRON_SNAPSHOTS}"
REMOTE_SCRIPT="${REMOTE_SCRIPT//__CRON_MONITOR__/$CRON_MONITOR}"

run_remote() {
  echo "=== install finance-integrity cron on ${REMOTE_USER}@${REMOTE_HOST} ==="
  # shellcheck disable=SC2029
  ssh "${REMOTE_USER}@${REMOTE_HOST}" bash -s <<<"$REMOTE_SCRIPT"
}

if [[ "$(hostname -s 2>/dev/null || true)" == "iobox" ]] || [[ -d "$BASE_DIR/backend" && "$(whoami)" == "io" ]]; then
  eval "$REMOTE_SCRIPT"
else
  run_remote
fi

echo "=== done ==="
