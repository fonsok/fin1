#!/usr/bin/env bash
# Combined monetary SSOT ops health: UserCashBalance drift + Settlement GL outbox.
#
# Usage:
#   ./scripts/check-monetary-ssot-health.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Monetary SSOT health (FIN1) ==="
echo ""

FAILED=0

run_check() {
  local label="$1"
  local script="$2"
  echo "--- $label ---"
  if "$script"; then
    echo ""
  else
    echo ""
    FAILED=1
  fi
}

run_check "UserCashBalance drift" "$SCRIPT_DIR/check-user-cash-balance-drift.sh"
run_check "Settlement GL outbox" "$SCRIPT_DIR/check-settlement-gl-outbox-health.sh"

if [ "$FAILED" -ne 0 ]; then
  echo "=== Monetary SSOT health: FAILED ==="
  exit 2
fi

echo "=== Monetary SSOT health: OK ==="
