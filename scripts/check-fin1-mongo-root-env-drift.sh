#!/usr/bin/env bash
# Prüft Drift/Duplikat für MONGO_INITDB_ROOT_PASSWORD zwischen Compose-Root-.env und backend/.env.
# Kanonisch (Best practice): nur ~/fin1-server/.env — siehe docker-compose.production.yml + Runbook 06A.
#
# Usage:
#   FIN1_SERVER_DIR=/home/io/fin1-server ./scripts/check-fin1-mongo-root-env-drift.sh
#   ./scripts/check-fin1-mongo-root-env-drift.sh   # default: $HOME/fin1-server
#
# Exit: 0 OK | 1 FAIL (fehlt in Root, Drift, oder --strict mit Duplikat)
set -euo pipefail

STRICT=0
if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
fi

ROOT="${FIN1_SERVER_DIR:-${HOME}/fin1-server}"
FE_ROOT="${ROOT}/.env"
FE_BE="${ROOT}/backend/.env"

get_val() {
  local f="$1"
  [[ -f "$f" ]] || { echo ""; return 0; }
  local line
  line=$(grep -E '^[[:space:]]*MONGO_INITDB_ROOT_PASSWORD=' "$f" 2>/dev/null | tail -1) || true
  [[ -z "${line}" ]] && { echo ""; return 0; }
  local v="${line#*=}"
  v="${v%$'\r'}"
  v="${v#\"}"
  v="${v%\"}"
  v="${v#\'}"
  v="${v%\'}"
  printf '%s' "$v"
}

err() { echo "check-fin1-mongo-root-env-drift: $*" >&2; }

VR=$(get_val "$FE_ROOT")
VB=$(get_val "$FE_BE")

if [[ -z "$VR" ]]; then
  err "FAIL: MONGO_INITDB_ROOT_PASSWORD fehlt in ${FE_ROOT} (kanonische Quelle für Compose-Interpolation)."
  exit 1
fi

if [[ -n "$VB" ]]; then
  if [[ "$VR" != "$VB" ]]; then
    err "FAIL: DRIFT — unterschiedliche Werte in ${FE_ROOT} vs ${FE_BE}."
    exit 1
  fi
  err "WARN: Duplikat — gleicher Wert auch in backend/.env. Best practice: Zeile aus backend/.env entfernen (Parse: PARSE_SERVER_DATABASE_URI kommt aus compose environment)."
  if [[ "$STRICT" -eq 1 ]]; then
    exit 1
  fi
  exit 0
fi

echo "check-fin1-mongo-root-env-drift: OK (Mongo-Root nur in ${FE_ROOT}, kein Eintrag in backend/.env)"
exit 0
