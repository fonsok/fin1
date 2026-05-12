#!/bin/bash
# Verify Desktop backups created under ~/Desktop/Backups_Fully
# Checks structure, critical files, and size plausibility.

set -euo pipefail

BACKUP_ROOT="${BACKUP_ROOT:-$HOME/Desktop/Backups_Fully}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pass_count=0
warn_count=0
fail_count=0

pass() {
  echo -e "${GREEN}PASS${NC} - $1"
  pass_count=$((pass_count + 1))
}

warn() {
  echo -e "${YELLOW}WARN${NC} - $1"
  warn_count=$((warn_count + 1))
}

fail() {
  echo -e "${RED}FAIL${NC} - $1"
  fail_count=$((fail_count + 1))
}

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Verify Desktop Backup${NC}"
echo -e "${BLUE}==========================================${NC}"
echo "Backup root: ${BACKUP_ROOT}"
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
  echo -e "${RED}Fehler:${NC} Keine Backups gefunden."
  exit 1
fi

VALID_BACKUPS=()
for dir in "${CANDIDATES[@]}"; do
  if [[ -d "${dir}/fin1-server" ]]; then
    VALID_BACKUPS+=("${dir}")
  fi
done

if [[ ${#VALID_BACKUPS[@]} -eq 0 ]]; then
  echo -e "${RED}Fehler:${NC} Keine gültigen Backups mit 'fin1-server' gefunden."
  exit 1
fi

echo "Verfügbare Backups:"
for i in "${!VALID_BACKUPS[@]}"; do
  idx=$((i + 1))
  remote_size="$(du -sh "${VALID_BACKUPS[$i]}/fin1-server" 2>/dev/null | awk '{print $1}')"
  local_size="n/a"
  if [[ -d "${VALID_BACKUPS[$i]}/FIN1" ]]; then
    local_size="$(du -sh "${VALID_BACKUPS[$i]}/FIN1" 2>/dev/null | awk '{print $1}')"
  fi
  echo "  [${idx}] $(basename "${VALID_BACKUPS[$i]}")   (fin1-server: ${remote_size}, FIN1: ${local_size})"
done
echo ""

read -r -p "Bitte Backup-Nummer wählen: " SELECTION
if ! [[ "${SELECTION}" =~ ^[0-9]+$ ]]; then
  echo -e "${RED}Fehler:${NC} Ungültige Eingabe."
  exit 1
fi
if (( SELECTION < 1 || SELECTION > ${#VALID_BACKUPS[@]} )); then
  echo -e "${RED}Fehler:${NC} Auswahl außerhalb des Bereichs."
  exit 1
fi

SELECTED_DIR="${VALID_BACKUPS[$((SELECTION - 1))]}"
REMOTE_BACKUP="${SELECTED_DIR}/fin1-server"
LOCAL_BACKUP="${SELECTED_DIR}/FIN1"

echo ""
echo -e "${BLUE}Prüfe Backup:${NC} ${SELECTED_DIR}"
echo ""

# Structure checks
[[ -d "${REMOTE_BACKUP}" ]] && pass "Ordner vorhanden: fin1-server" || fail "Ordner fehlt: fin1-server"
[[ -d "${LOCAL_BACKUP}" ]] && pass "Ordner vorhanden: FIN1" || warn "Ordner fehlt: FIN1 (optional, falls nur Server-Backup gewünscht)"

# Critical files in fin1-server
[[ -f "${REMOTE_BACKUP}/docker-compose.production.yml" ]] && pass "Datei vorhanden: docker-compose.production.yml" || fail "Datei fehlt: docker-compose.production.yml"
[[ -f "${REMOTE_BACKUP}/docker-compose.yml" ]] && pass "Datei vorhanden: docker-compose.yml" || warn "Datei fehlt: docker-compose.yml"
[[ -f "${REMOTE_BACKUP}/backend/.env" ]] && pass "Datei vorhanden: backend/.env" || warn "Datei fehlt: backend/.env"
[[ -d "${REMOTE_BACKUP}/backend/parse-server" ]] && pass "Ordner vorhanden: backend/parse-server" || fail "Ordner fehlt: backend/parse-server"

# Optional but useful
[[ -d "${REMOTE_BACKUP}/backend/nginx/ssl" ]] && pass "Ordner vorhanden: backend/nginx/ssl" || warn "Ordner fehlt: backend/nginx/ssl (TLS ggf. extern)"
[[ -d "${REMOTE_BACKUP}/backend/parse-server/certs" ]] && pass "Ordner vorhanden: backend/parse-server/certs" || warn "Ordner fehlt: backend/parse-server/certs"

# Size plausibility
remote_bytes=$(du -sk "${REMOTE_BACKUP}" | awk '{print $1}')
remote_mb=$((remote_bytes / 1024))
if (( remote_mb >= 200 )); then
  pass "Größe fin1-server plausibel: ${remote_mb} MB"
elif (( remote_mb >= 50 )); then
  warn "Größe fin1-server eher klein: ${remote_mb} MB (prüfen, ob vollständig)"
else
  fail "Größe fin1-server sehr klein: ${remote_mb} MB (wahrscheinlich unvollständig)"
fi

if [[ -d "${LOCAL_BACKUP}" ]]; then
  local_bytes=$(du -sk "${LOCAL_BACKUP}" | awk '{print $1}')
  local_mb=$((local_bytes / 1024))
  if (( local_mb >= 50 )); then
    pass "Größe FIN1 plausibel: ${local_mb} MB"
  elif (( local_mb >= 10 )); then
    warn "Größe FIN1 eher klein: ${local_mb} MB"
  else
    fail "Größe FIN1 sehr klein: ${local_mb} MB"
  fi
fi

echo ""
echo -e "${BLUE}==========================================${NC}"
echo "Ergebnis:"
echo "  PASS: ${pass_count}"
echo "  WARN: ${warn_count}"
echo "  FAIL: ${fail_count}"
echo -e "${BLUE}==========================================${NC}"

if (( fail_count > 0 )); then
  exit 2
fi

exit 0
