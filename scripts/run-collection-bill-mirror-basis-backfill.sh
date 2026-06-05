#!/usr/bin/env bash
# Backfill investorCollectionBill metadata (totalBuyCost, netSellAmount, returnPercentage).
# Dry-run by default; APPLY=1 on the server host after review.
#
# Usage on fin1-server (see Documentation/RETURN_CALCULATION_SCHEMAS.md):
#   APPLY=0 ./scripts/run-collection-bill-mirror-basis-backfill.sh
#   APPLY=1 ./scripts/run-collection-bill-mirror-basis-backfill.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_SCRIPT="$PROJECT_ROOT/backend/scripts/reconcile-collection-bill-mirror-basis.js"

if [[ ! -f "$BACKEND_SCRIPT" ]]; then
  echo "Missing $BACKEND_SCRIPT" >&2
  exit 1
fi

BASE_DIR="${BASE_DIR:-/home/io/fin1-server}"
COMPOSE_FILE="${COMPOSE_FILE:-$BASE_DIR/docker-compose.production.yml}"
APPLY="${APPLY:-0}"

echo "=== Collection bill mirror-basis backfill (APPLY=$APPLY) ==="
echo "Script: $BACKEND_SCRIPT"
echo ""

if [[ -f "$COMPOSE_FILE" ]]; then
  MONGO_PASSWORD=""
  for candidate in "${ENV_FILE:-}" "$BASE_DIR/.env" "$BASE_DIR/backend/.env"; do
    [[ -z "$candidate" || ! -f "$candidate" ]] && continue
    MONGO_PASSWORD="$(grep -E '^MONGO_INITDB_ROOT_PASSWORD=' "$candidate" | tail -1 | cut -d= -f2- | tr -d '"' | tr -d "'")"
    [[ -n "$MONGO_PASSWORD" ]] && break
  done
  if [[ -z "$MONGO_PASSWORD" ]]; then
    echo "ERROR: MONGO_INITDB_ROOT_PASSWORD not found in $ENV_FILE" >&2
    exit 2
  fi

  docker compose -f "$COMPOSE_FILE" cp "$BACKEND_SCRIPT" mongodb:/tmp/reconcile-collection-bill-mirror-basis.js
  docker compose -f "$COMPOSE_FILE" exec -T -e APPLY="$APPLY" mongodb mongosh \
    --quiet --username admin --password "$MONGO_PASSWORD" \
    --authenticationDatabase admin \
    fin1 /tmp/reconcile-collection-bill-mirror-basis.js
else
  echo "Compose file not found ($COMPOSE_FILE). Run mongosh manually with:" >&2
  echo "  APPLY=$APPLY mongosh …/reconcile-collection-bill-mirror-basis.js" >&2
  exit 1
fi

echo ""
echo "=== Done ==="
