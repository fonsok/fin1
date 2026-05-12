#!/bin/bash
# Sync remote fin1-server + local FIN1 into Desktop backup folder.
# Run this script from a Mac terminal.

set -euo pipefail

REMOTE_HOST="${1:-192.168.178.20}"
REMOTE_USER="${2:-io}"
REMOTE_DIR="${3:-~/fin1-server}"

LOCAL_FIN1_DIR="${LOCAL_FIN1_DIR:-$HOME/app/FIN1}"
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/Desktop/Backups_Fully}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
TARGET_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
TARGET_REMOTE_DIR="${TARGET_DIR}/fin1-server"
TARGET_LOCAL_DIR="${TARGET_DIR}/FIN1"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}FIN1 Full Backup to Mac Desktop${NC}"
echo -e "${BLUE}==========================================${NC}"
echo "Remote source: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"
echo "Local source:  ${LOCAL_FIN1_DIR}"
echo "Target:        ${TARGET_DIR}"
echo ""

if [[ ! -d "${LOCAL_FIN1_DIR}" ]]; then
  echo -e "${RED}Fehler:${NC} Lokaler Ordner nicht gefunden: ${LOCAL_FIN1_DIR}"
  exit 1
fi

echo -e "${YELLOW}[1/4]${NC} Zielordner anlegen..."
mkdir -p "${TARGET_REMOTE_DIR}" "${TARGET_LOCAL_DIR}"
echo -e "${GREEN}✓${NC} ${TARGET_DIR}"

echo -e "${YELLOW}[2/4]${NC} SSH-Verbindung prüfen..."
if ! ssh -o ConnectTimeout=8 -o BatchMode=yes "${REMOTE_USER}@${REMOTE_HOST}" "echo ok" >/dev/null 2>&1; then
  echo -e "${RED}Fehler:${NC} SSH-Verbindung zu ${REMOTE_USER}@${REMOTE_HOST} fehlgeschlagen."
  echo "Tipp: ssh-copy-id ${REMOTE_USER}@${REMOTE_HOST}"
  exit 1
fi
echo -e "${GREEN}✓${NC} SSH-Verbindung ok"

echo -e "${YELLOW}[3/4]${NC} Remote fin1-server auf Mac kopieren..."
rsync -avz --progress \
  "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/" "${TARGET_REMOTE_DIR}/"
echo -e "${GREEN}✓${NC} Remote Backup fertig"

echo -e "${YELLOW}[4/4]${NC} Lokalen FIN1-Ordner kopieren..."
rsync -av --progress \
  "${LOCAL_FIN1_DIR}/" "${TARGET_LOCAL_DIR}/"
echo -e "${GREEN}✓${NC} Lokales Backup fertig"

echo ""
echo -e "${GREEN}Backup abgeschlossen.${NC}"
echo "Ordner:"
echo "  - ${TARGET_REMOTE_DIR}"
echo "  - ${TARGET_LOCAL_DIR}"
echo ""
echo -e "${BLUE}Größenübersicht:${NC}"
du -sh "${TARGET_REMOTE_DIR}" "${TARGET_LOCAL_DIR}" 2>/dev/null || true
echo ""
echo "Hinweis: Vollbackup ohne Excludes, bewusst ohne --delete."
