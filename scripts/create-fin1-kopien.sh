#!/usr/bin/env bash
# Erstellt zeitgestempelte Quellcode-Kopien (standard: schlank, ohne Build-Artefakte):
#   Mac:    ~/app/FIN1           → ~/app/FIN1_Kopie_<Zeitstempel>_
#   Ubuntu: ~/fin1-server        → ~/fin1-server_Kopie_<Zeitstempel>_
#
# Standard (~40 MB Mac): schließt build/, node_modules/, .git/ usw. aus
# (gleiche Logik wie scripts/clean-for-export.sh). Vollkopie: FIN1_FULL_COPY=1
#
# Vom Mac-Home-Verzeichnis ausführbar, z. B.:
#   bash ~/app/FIN1/scripts/create-fin1-kopien.sh
#   bash app/FIN1/scripts/create-fin1-kopien.sh
#
# Optional:
#   FIN1_FULL_COPY=1              Komplette Spiegelung inkl. build/node_modules
#   FIN1_INCLUDE_GIT=1            .git/ mitkopieren (nur bei schlanker Kopie)
#   FIN1_LOCAL_DIR=~/app/FIN1
#   FIN1_APP_DIR=~/app
#   FIN1_REMOTE_HOST=192.168.178.20
#   FIN1_REMOTE_USER=io
#   FIN1_REMOTE_SERVER_DIR=~/fin1-server

set -euo pipefail

FIN1_LOCAL_DIR="${FIN1_LOCAL_DIR:-$HOME/app/FIN1}"
FIN1_APP_DIR="${FIN1_APP_DIR:-$HOME/app}"
FIN1_REMOTE_HOST="${FIN1_REMOTE_HOST:-192.168.178.20}"
FIN1_REMOTE_USER="${FIN1_REMOTE_USER:-io}"
FIN1_REMOTE_SERVER_DIR="${FIN1_REMOTE_SERVER_DIR:-~/fin1-server}"
FIN1_FULL_COPY="${FIN1_FULL_COPY:-0}"
FIN1_INCLUDE_GIT="${FIN1_INCLUDE_GIT:-0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Englische Monatskürzel → z. B. 05Jun17h30
timestamp() {
  LC_TIME=C date +%d%b%Hh%M
}

# Schlank: nur Quellcode + Config; Build/Deps lokal nachinstallierbar (npm ci, xcodebuild).
MAC_LEAN_EXCLUDES=(
  --exclude=build/
  --exclude=DerivedData/
  --exclude=.build/
  --exclude=admin-portal/node_modules/
  --exclude=admin-portal/dist/
  --exclude=admin-portal/coverage/
  --exclude=backend/parse-server/node_modules/
  --exclude=admin/
  --exclude=__pycache__/
  --exclude=.venv_*/
  --exclude=fin1-return-contract.bundle/
  --exclude=.tmp_*/
  --exclude=.DS_Store
)

REMOTE_LEAN_EXCLUDES=(
  --exclude=node_modules/
  --exclude=**/logs/
  --exclude=*.log
  --exclude=__pycache__/
  --exclude=.git/
  --exclude=.DS_Store
)

STAMP="$(timestamp)"
MAC_COPY_NAME="FIN1_Kopie_${STAMP}_"
REMOTE_COPY_NAME="fin1-server_Kopie_${STAMP}_"
MAC_TARGET="${FIN1_APP_DIR%/}/${MAC_COPY_NAME}"

if [[ "${FIN1_FULL_COPY}" == "1" ]]; then
  COPY_MODE="vollständig (inkl. build, node_modules)"
else
  COPY_MODE="schlank (ohne build/node_modules/.git)"
fi

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}FIN1 Kopien erstellen${NC}"
echo -e "${BLUE}==========================================${NC}"
echo "Modus:          ${COPY_MODE}"
echo "Zeitstempel:    ${STAMP}"
echo "Mac Quelle:      ${FIN1_LOCAL_DIR}"
echo "Mac Ziel:        ${MAC_TARGET}"
echo "Ubuntu Quelle:   ${FIN1_REMOTE_USER}@${FIN1_REMOTE_HOST}:${FIN1_REMOTE_SERVER_DIR}"
echo "Ubuntu Ziel:     ${FIN1_REMOTE_USER}@${FIN1_REMOTE_HOST}:~/${REMOTE_COPY_NAME}"
echo ""

if [[ ! -d "${FIN1_LOCAL_DIR}" ]]; then
  echo -e "${RED}Fehler:${NC} Mac-Quellordner nicht gefunden: ${FIN1_LOCAL_DIR}"
  exit 1
fi

if [[ -e "${MAC_TARGET}" ]]; then
  echo -e "${RED}Fehler:${NC} Mac-Ziel existiert bereits: ${MAC_TARGET}"
  exit 1
fi

mkdir -p "${FIN1_APP_DIR}"

MAC_RSYNC_OPTS=(-a --progress)
if [[ "${FIN1_FULL_COPY}" != "1" ]]; then
  MAC_RSYNC_OPTS+=("${MAC_LEAN_EXCLUDES[@]}")
  if [[ "${FIN1_INCLUDE_GIT}" != "1" ]]; then
    MAC_RSYNC_OPTS+=(--exclude=.git/)
  fi
fi

echo -e "${YELLOW}[1/3]${NC} Mac-Kopie erstellen..."
rsync "${MAC_RSYNC_OPTS[@]}" \
  "${FIN1_LOCAL_DIR}/" "${MAC_TARGET}/"
echo -e "${GREEN}✓${NC} Mac-Kopie fertig: ${MAC_TARGET}"

echo ""
echo -e "${YELLOW}[2/3]${NC} SSH-Verbindung zum Ubuntu-Rechner prüfen..."
if ! ssh -o ConnectTimeout=8 -o BatchMode=yes "${FIN1_REMOTE_USER}@${FIN1_REMOTE_HOST}" "echo ok" >/dev/null 2>&1; then
  echo -e "${RED}Fehler:${NC} SSH zu ${FIN1_REMOTE_USER}@${FIN1_REMOTE_HOST} fehlgeschlagen."
  echo "Mac-Kopie wurde bereits erstellt: ${MAC_TARGET}"
  echo "Tipp: ssh-copy-id ${FIN1_REMOTE_USER}@${FIN1_REMOTE_HOST}"
  exit 1
fi
echo -e "${GREEN}✓${NC} SSH-Verbindung ok"

echo ""
echo -e "${YELLOW}[3/3]${NC} Ubuntu-Kopie erstellen (auf dem Server)..."
ssh "${FIN1_REMOTE_USER}@${FIN1_REMOTE_HOST}" bash -s -- \
  "${FIN1_REMOTE_SERVER_DIR}" "${REMOTE_COPY_NAME}" "${FIN1_FULL_COPY}" <<'REMOTE_SCRIPT'
set -euo pipefail

REMOTE_SRC="${1/#\~/$HOME}"
REMOTE_DST="${HOME}/${2}"
FULL_COPY="${3:-0}"

if [[ ! -d "${REMOTE_SRC}" ]]; then
  echo "Fehler: Quellordner nicht gefunden: ${REMOTE_SRC}" >&2
  exit 1
fi

if [[ -e "${REMOTE_DST}" ]]; then
  echo "Fehler: Ziel existiert bereits: ${REMOTE_DST}" >&2
  exit 1
fi

mkdir -p "${REMOTE_DST}"

if [[ "${FULL_COPY}" == "1" ]]; then
  cp -a "${REMOTE_SRC}/." "${REMOTE_DST}/"
else
  rsync -a \
    --exclude=node_modules/ \
    --exclude='**/logs/' \
    --exclude='*.log' \
    --exclude=__pycache__/ \
    --exclude=.git/ \
    --exclude=.DS_Store \
    "${REMOTE_SRC}/" "${REMOTE_DST}/"
fi

echo "Ubuntu-Kopie fertig: ${REMOTE_DST}"
du -sh "${REMOTE_DST}" 2>/dev/null || true
REMOTE_SCRIPT

echo ""
echo -e "${GREEN}Alle Kopien erstellt.${NC}"
echo "Mac:    ${MAC_TARGET}"
echo "Ubuntu: ${FIN1_REMOTE_USER}@${FIN1_REMOTE_HOST}:~/${REMOTE_COPY_NAME}"
echo ""
echo -e "${BLUE}Größenübersicht (Mac):${NC}"
du -sh "${FIN1_LOCAL_DIR}" "${MAC_TARGET}" 2>/dev/null || true
if [[ "${FIN1_FULL_COPY}" != "1" ]]; then
  echo ""
  echo "Hinweis: Schlank-Kopie ohne Build-Artefakte. Wiederherstellen mit:"
  echo "  iOS:          xcodebuild / Xcode"
  echo "  admin-portal: cd admin-portal && npm ci"
  echo "  parse-server: cd backend/parse-server && npm ci"
fi
