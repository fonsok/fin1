#!/bin/bash
# Run full backup then verify the newest Desktop backup.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="${SCRIPT_DIR}/sync-server-and-local-to-mac.sh"
VERIFY_SCRIPT="${SCRIPT_DIR}/verify-desktop-backup.sh"
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/Desktop/Backups_Fully}"

REMOTE_HOST="${1:-192.168.178.24}"
REMOTE_USER="${2:-io}"
REMOTE_DIR="${3:-~/fin1-server}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}FIN1 Backup + Verify (Desktop)${NC}"
echo -e "${BLUE}==========================================${NC}"
echo "Remote: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"
echo "Backup root: ${BACKUP_ROOT}"
echo ""

if [[ ! -x "${BACKUP_SCRIPT}" ]]; then
  echo -e "${RED}Fehler:${NC} Backup-Script fehlt/ist nicht ausführbar: ${BACKUP_SCRIPT}"
  exit 1
fi

if [[ ! -x "${VERIFY_SCRIPT}" ]]; then
  echo -e "${RED}Fehler:${NC} Verify-Script fehlt/ist nicht ausführbar: ${VERIFY_SCRIPT}"
  exit 1
fi

echo -e "${YELLOW}[1/3]${NC} Backup erstellen..."
"${BACKUP_SCRIPT}" "${REMOTE_HOST}" "${REMOTE_USER}" "${REMOTE_DIR}"

echo ""
echo -e "${YELLOW}[2/3]${NC} Neuestes Backup ermitteln..."
LATEST_BACKUP="$(ls -1dt "${BACKUP_ROOT}"/* 2>/dev/null | head -n 1 || true)"
if [[ -z "${LATEST_BACKUP}" || ! -d "${LATEST_BACKUP}" ]]; then
  echo -e "${RED}Fehler:${NC} Konnte kein Backup in ${BACKUP_ROOT} finden."
  exit 1
fi
echo -e "${GREEN}✓${NC} Neuestes Backup: ${LATEST_BACKUP}"

echo ""
echo -e "${YELLOW}[3/3]${NC} Backup verifizieren..."
echo "Hinweis: Bitte im Auswahlmenü das neueste Backup wählen:"
echo "  $(basename "${LATEST_BACKUP}")"
echo ""
"${VERIFY_SCRIPT}"

echo ""
echo -e "${GREEN}Backup + Verify abgeschlossen.${NC}"
