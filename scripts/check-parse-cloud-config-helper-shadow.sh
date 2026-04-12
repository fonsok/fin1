#!/usr/bin/env bash
# Fail if legacy cloud/utils/configHelper.js exists — it shadows utils/configHelper/
# when code used require('.../configHelper') without /index.js (Node resolution).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHADOW="$ROOT/backend/parse-server/cloud/utils/configHelper.js"
if [[ -f "$SHADOW" ]]; then
  echo "ERROR: Refusing to continue: $SHADOW exists."
  echo "  Node resolves require('.../configHelper') to this file before the configHelper/ directory."
  echo "  Remove the file; the canonical module is backend/parse-server/cloud/utils/configHelper/index.js"
  echo "  and all requires must use '.../configHelper/index.js'."
  exit 1
fi
echo "OK: no Parse Cloud configHelper.js shadow file."
