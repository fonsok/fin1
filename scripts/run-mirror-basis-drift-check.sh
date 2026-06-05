#!/usr/bin/env bash
set -euo pipefail

# Backward-compatible wrapper → unified finance-integrity snapshot runner.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${1:-}" == "--catchup" ]]; then
  exec "$SCRIPT_DIR/run-finance-integrity-snapshots.sh" --catchup --only mirror-basis
fi
exec "$SCRIPT_DIR/run-finance-integrity-snapshots.sh" --only mirror-basis
