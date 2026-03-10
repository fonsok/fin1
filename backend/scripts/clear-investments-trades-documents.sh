#!/usr/bin/env bash
# ============================================================================
# Clear investments, trades, and related documents (for testing only).
# Run from repo root or from ~/fin1-server/scripts on the server.
#
# Usage (local, from repo root):
#   CONFIRM_CLEAR_TEST_DATA=1 ./backend/scripts/clear-investments-trades-documents.sh
#
# On server (io@iobox / 192.168.178.20), after copying scripts to ~/fin1-server/scripts:
#   cd ~/fin1-server/scripts && CONFIRM_CLEAR_TEST_DATA=1 ./clear-investments-trades-documents.sh
#
# Copy to server (from your machine, repo root):
#   scp backend/scripts/clear-investments-trades-documents.sh backend/scripts/clear-investments-trades-documents.js io@192.168.178.20:~/fin1-server/scripts/
#
# Requires: MongoDB (Docker container fin1-mongodb, or mongosh on PATH with MONGO_URI).
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Credentials: prefer MONGO_PASSWORD env; else read from ~/fin1-server/.env (MONGO_INITDB_ROOT_PASSWORD) if present
MONGO_USER="${MONGO_USER:-admin}"
if [ -n "${MONGO_PASSWORD}" ]; then
  MONGO_PASS="${MONGO_PASSWORD}"
elif [ -f "${HOME}/fin1-server/.env" ]; then
  MONGO_PASS="$(grep -E '^MONGO_INITDB_ROOT_PASSWORD=' "${HOME}/fin1-server/.env" 2>/dev/null | cut -d= -f2-)" || MONGO_PASS="fin1-mongo-password"
else
  MONGO_PASS="${MONGO_PASSWORD:-fin1-mongo-password}"
fi
MONGO_URI="${MONGO_URI:-mongodb://${MONGO_USER}:${MONGO_PASS}@localhost:27018/fin1?authSource=admin}"

if [ "${CONFIRM_CLEAR_TEST_DATA}" != "1" ]; then
  echo "This script deletes all investments, trades, orders, invoices, and related documents."
  echo "Set CONFIRM_CLEAR_TEST_DATA=1 to confirm (testing only)."
  echo "  Example: CONFIRM_CLEAR_TEST_DATA=1 $0"
  exit 1
fi

echo "Clearing investments, trades, and related documents..."

if command -v docker >/dev/null 2>&1 && docker exec fin1-mongodb true 2>/dev/null; then
  echo "Using MongoDB in Docker (fin1-mongodb)..."
  DOCKER_URI="mongodb://${MONGO_USER}:${MONGO_PASS}@localhost:27017/fin1?authSource=admin"
  if ! docker exec -i fin1-mongodb mongosh "$DOCKER_URI" < "$SCRIPT_DIR/clear-investments-trades-documents.js"; then
    echo "MongoDB auth failed. Set MONGO_USER and MONGO_PASSWORD to match your fin1-mongodb container, e.g.:"
    echo "  MONGO_PASSWORD=yourActualPassword CONFIRM_CLEAR_TEST_DATA=1 $0"
    exit 1
  fi
elif command -v mongosh >/dev/null 2>&1; then
  echo "Using mongosh on host (MONGO_URI)..."
  mongosh "$MONGO_URI" --file "$SCRIPT_DIR/clear-investments-trades-documents.js"
else
  echo "Error: Need either Docker (container fin1-mongodb) or mongosh on PATH."
  echo "  With Docker: start stack then run again with CONFIRM_CLEAR_TEST_DATA=1."
  echo "  If Authentication failed: set MONGO_PASSWORD=yourActualPassword (from your .env / docker-compose)."
  exit 1
fi

echo "Done."
