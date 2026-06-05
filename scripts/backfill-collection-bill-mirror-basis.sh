#!/usr/bin/env bash
# Dry-run / apply backfill for investor Collection Bill metadata (mirror-basis SSOT).
# Sets grossProfit, commission, netProfit, returnPercentage, totalBuyCost, netSellAmount, buyLeg, sellLeg.
#
# Usage (local, tunnel to Mongo):
#   ./scripts/backfill-collection-bill-mirror-basis.sh
#   APPLY=1 ./scripts/backfill-collection-bill-mirror-basis.sh
#   DOC_ID=<objectId> ./scripts/backfill-collection-bill-mirror-basis.sh
#
# Requires: MONGO_URL (or default from script), node, mongodb driver via parse-server deps.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "${MONGO_URL:-}" ]]; then
  echo "⚠️  MONGO_URL not set — using script default (localhost tunnel)."
fi

echo "Mode: ${APPLY:-DRY-RUN (set APPLY=1 to write)}"
node backend/scripts/backfill-collection-bill-mirror-basis.js
