#!/bin/bash
# Restore ~/fin1-server on Ubuntu from a selected Mac Desktop backup.
# Source backups: ~/Desktop/Backups_Fully/<timestamp>/fin1-server

set -euo pipefail

REMOTE_HOST="${1:-192.168.178.20}"
REMOTE_USER="${2:-io}"
REMOTE_DIR="${3:-~/fin1-server}"
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/Desktop/Backups_Fully}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Restore fin1-server from Desktop backup${NC}"
echo -e "${BLUE}==========================================${NC}"
echo "Backup root: ${BACKUP_ROOT}"
echo "Remote:      ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"
echo ""

if [[ ! -d "${BACKUP_ROOT}" ]]; then
  echo -e "${RED}Fehler:${NC} Backup-Ordner nicht gefunden: ${BACKUP_ROOT}"
  exit 1
fi

CANDIDATES=()
while IFS= read -r line; do
  CANDIDATES+=("$line")
done < <(ls -1dt "${BACKUP_ROOT}"/* 2>/dev/null || true)

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  echo -e "${RED}Fehler:${NC} Keine Backup-Ordner in ${BACKUP_ROOT} gefunden."
  exit 1
fi

VALID_BACKUPS=()
for dir in "${CANDIDATES[@]}"; do
  if [[ -d "${dir}/fin1-server" ]]; then
    VALID_BACKUPS+=("${dir}")
  fi
done

if [[ ${#VALID_BACKUPS[@]} -eq 0 ]]; then
  echo -e "${RED}Fehler:${NC} Keine gültigen Backups mit Unterordner 'fin1-server' gefunden."
  exit 1
fi

echo -e "${YELLOW}Verfügbare Desktop-Backups:${NC}"
for i in "${!VALID_BACKUPS[@]}"; do
  idx=$((i + 1))
  size="$(du -sh "${VALID_BACKUPS[$i]}/fin1-server" 2>/dev/null | awk '{print $1}')"
  echo "  [${idx}] $(basename "${VALID_BACKUPS[$i]}")   (fin1-server: ${size})"
done
echo ""

read -r -p "Bitte Backup-Nummer wählen: " SELECTION
if ! [[ "${SELECTION}" =~ ^[0-9]+$ ]]; then
  echo -e "${RED}Fehler:${NC} Ungültige Eingabe."
  exit 1
fi

if (( SELECTION < 1 || SELECTION > ${#VALID_BACKUPS[@]} )); then
  echo -e "${RED}Fehler:${NC} Auswahl außerhalb des gültigen Bereichs."
  exit 1
fi

SELECTED_DIR="${VALID_BACKUPS[$((SELECTION - 1))]}"
SOURCE_DIR="${SELECTED_DIR}/fin1-server"

echo ""
echo -e "${BLUE}Ausgewähltes Backup:${NC} ${SELECTED_DIR}"
echo -e "${BLUE}Quelle:${NC} ${SOURCE_DIR}"
echo ""
echo -e "${YELLOW}WARNUNG:${NC} Dies überschreibt Dateien auf dem Server unter ${REMOTE_DIR}."
read -r -p "Zum Fortfahren 'yes' eingeben: " CONFIRM
if [[ "${CONFIRM}" != "yes" ]]; then
  echo "Abgebrochen."
  exit 0
fi

echo ""
echo -e "${YELLOW}[1/3]${NC} SSH-Verbindung prüfen..."
if ! ssh -o ConnectTimeout=8 -o BatchMode=yes "${REMOTE_USER}@${REMOTE_HOST}" "echo ok" >/dev/null 2>&1; then
  echo -e "${RED}Fehler:${NC} SSH-Verbindung fehlgeschlagen."
  exit 1
fi
echo -e "${GREEN}✓${NC} SSH-Verbindung ok"

echo -e "${YELLOW}[2/3]${NC} Backup auf Server kopieren..."
rsync -av --progress "${SOURCE_DIR}/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/"
echo -e "${GREEN}✓${NC} Restore-Dateien übertragen"

echo -e "${YELLOW}[3/3]${NC} Optional: Docker-Stack starten..."
read -r -p "Jetzt 'docker compose -f docker-compose.production.yml up -d' ausführen? (y/n): " START_STACK
if [[ "${START_STACK}" =~ ^[Yy]$ ]]; then
  ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ${REMOTE_DIR} && docker compose -f docker-compose.production.yml up -d && docker compose -f docker-compose.production.yml ps"
  echo -e "${GREEN}✓${NC} Docker-Stack gestartet"
else
  echo "Übersprungen. Manuell ausführen:"
  echo "ssh ${REMOTE_USER}@${REMOTE_HOST} 'cd ${REMOTE_DIR} && docker compose -f docker-compose.production.yml up -d'"
fi

echo ""
echo -e "${GREEN}Restore abgeschlossen.${NC}"
echo "Quelle: ${SOURCE_DIR}"
echo "Ziel:   ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"
