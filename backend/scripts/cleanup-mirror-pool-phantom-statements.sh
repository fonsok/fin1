#!/usr/bin/env bash
# Remove phantom trader AccountStatement rows for MIRROR_POOL trades.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MONGO_USER="${MONGO_USER:-admin}"
if [ -n "${MONGO_PASSWORD:-}" ]; then
  MONGO_PASS="${MONGO_PASSWORD}"
elif [ -f "${HOME}/fin1-server/.env" ]; then
  MONGO_PASS="$(grep -E '^MONGO_INITDB_ROOT_PASSWORD=' "${HOME}/fin1-server/.env" 2>/dev/null | cut -d= -f2-)" || MONGO_PASS="fin1-mongo-password"
else
  MONGO_PASS="${MONGO_PASSWORD:-fin1-mongo-password}"
fi

MONGO_URI="${MONGO_URI:-mongodb://${MONGO_USER}:${MONGO_PASS}@localhost:27018/fin1?authSource=admin}"
EXECUTE="${CONFIRM_MIRROR_POOL_STMT_CLEANUP:-0}"

if [ "${EXECUTE}" != "1" ]; then
  echo "Dry-run: listing phantom MIRROR_POOL AccountStatement rows."
  echo "Set CONFIRM_MIRROR_POOL_STMT_CLEANUP=1 to delete and rebuild balances."
fi

run_mongosh() {
  local uri="$1"
  {
    echo "var CONFIRM_MIRROR_POOL_STMT_CLEANUP='${EXECUTE}';"
    cat "$SCRIPT_DIR/cleanup-mirror-pool-phantom-statements.js"
  } | docker exec -i fin1-mongodb mongosh "$uri" --quiet
}

if command -v docker >/dev/null 2>&1 && docker exec fin1-mongodb true 2>/dev/null; then
  DOCKER_URI="mongodb://${MONGO_USER}:${MONGO_PASS}@localhost:27017/fin1?authSource=admin"
  run_mongosh "$DOCKER_URI"
elif command -v mongosh >/dev/null 2>&1; then
  mongosh "$MONGO_URI" \
    --eval "var CONFIRM_MIRROR_POOL_STMT_CLEANUP='${EXECUTE}';" \
    --file "$SCRIPT_DIR/cleanup-mirror-pool-phantom-statements.js"
else
  echo "Error: need Docker (fin1-mongodb) or mongosh."
  exit 1
fi
