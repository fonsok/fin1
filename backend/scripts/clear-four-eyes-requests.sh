#!/usr/bin/env bash
# ============================================================================
# Clear all FourEyesRequest documents (for testing only).
# Run from repo root:  ./backend/scripts/clear-four-eyes-requests.sh
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONGO_URI="${MONGO_URI:-mongodb://admin:fin1-mongo-password@localhost:27018/fin1?authSource=admin}"

# If MongoDB runs in Docker, use docker exec so we don't need mongosh on host
if command -v docker >/dev/null 2>&1 && docker exec fin1-mongodb true 2>/dev/null; then
  echo "Using MongoDB in Docker (fin1-mongodb)..."
  docker exec -i fin1-mongodb mongosh "mongodb://admin:fin1-mongo-password@localhost:27017/fin1?authSource=admin" < "$SCRIPT_DIR/clear-four-eyes-requests.js"
elif command -v mongosh >/dev/null 2>&1; then
  echo "Using mongosh on host (MONGO_URI)..."
  mongosh "$MONGO_URI" --file "$SCRIPT_DIR/clear-four-eyes-requests.js"
else
  echo "Error: Need either Docker (container fin1-mongodb) or mongosh on PATH."
  echo "  With Docker: start stack then run this script again."
  echo "  Or run manually: docker exec -i fin1-mongodb mongosh 'mongodb://admin:fin1-mongo-password@localhost:27017/fin1?authSource=admin' < $SCRIPT_DIR/clear-four-eyes-requests.js"
  exit 1
fi
