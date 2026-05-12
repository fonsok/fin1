#!/bin/bash
# Einmalige Migration: MongoDB-Collection PlatformLedgerEntry → AppLedgerEntry umbenennen.
# Nur nötig in einer Umgebung, in der noch die alte Collection existiert (z. B. neuer Server,
# Staging mit alter DB-Kopie). Nach dem ersten Ausführen nicht mehr bei jedem Deploy ausführen.
# Run on the server: ./backend/scripts/migrate-platform-ledger-to-app-ledger.sh
# Or from your machine: ssh io@192.168.178.20 'bash -s' < backend/scripts/migrate-platform-ledger-to-app-ledger.sh
# Requires: FIN1_SERVER or current dir is fin1-server; .env with MONGO_INITDB_ROOT_PASSWORD

set -euo pipefail

FIN1_SERVER="${FIN1_SERVER:-/home/io/fin1-server}"
ENV_FILE="${FIN1_SERVER}/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: .env not found at $ENV_FILE"
  exit 1
fi

# shellcheck source=/dev/null
MONGO_PASS=$(grep MONGO_INITDB_ROOT_PASSWORD "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
if [[ -z "${MONGO_PASS}" ]]; then
  echo "Error: MONGO_INITDB_ROOT_PASSWORD not found in .env"
  exit 1
fi

MONGO_URI="mongodb://admin:${MONGO_PASS}@localhost:27017/fin1?authSource=admin"

echo "Checking for collection PlatformLedgerEntry..."
COUNT=$(docker exec fin1-mongodb mongosh "$MONGO_URI" --quiet --eval 'db.PlatformLedgerEntry.countDocuments({})' 2>/dev/null || echo "0")
if [[ "${COUNT}" =~ ^[0-9]+$ ]] && [[ "$COUNT" -gt 0 ]]; then
  echo "Found $COUNT document(s) in PlatformLedgerEntry. Renaming collection to AppLedgerEntry..."
  docker exec fin1-mongodb mongosh "$MONGO_URI" --eval 'db.PlatformLedgerEntry.renameCollection("AppLedgerEntry")'
  echo "Done. Collection is now AppLedgerEntry."
elif [[ "${COUNT}" =~ ^[0-9]+$ ]] && [[ "$COUNT" -eq 0 ]]; then
  echo "Collection PlatformLedgerEntry exists but is empty. Renaming anyway..."
  docker exec fin1-mongodb mongosh "$MONGO_URI" --eval 'db.PlatformLedgerEntry.renameCollection("AppLedgerEntry")'
  echo "Done."
else
  echo "Collection PlatformLedgerEntry not found or error (maybe already renamed?). Checking AppLedgerEntry..."
  EXISTS=$(docker exec fin1-mongodb mongosh "$MONGO_URI" --quiet --eval 'db.getCollectionNames().includes("AppLedgerEntry")' 2>/dev/null || echo "false")
  if [[ "$EXISTS" == "true" ]]; then
    echo "AppLedgerEntry already exists. Migration likely already done. Nothing to do."
  else
    echo "Could not access PlatformLedgerEntry. Ensure MongoDB is running and credentials in .env are correct."
    exit 1
  fi
fi
